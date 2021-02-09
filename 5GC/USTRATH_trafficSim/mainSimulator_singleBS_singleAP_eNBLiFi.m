% Li-Drive - single macro eNB and single LiFi AP
% LiFi AP has a storage capacity.
% UE uploads the requested content to the LiFi AP.
% If an UE requests the content that is already available in the LiFi AP,
% it downloads it from the LiFi AP.
% Thus, (i) burden on the macrocellular network will be reduced;
% (ii) the latency will be reduced;
% (iii) UE does not need to have a huge storage capability.
%
% Assumptions/Rules:
% (1) An UE cannot request another content if the UE has not received the
%     already requested content.
% (2) An UE can request the same content in another arrival time if it does
%     satisfy the rule (1).
% (3) UE selection for Poisson arrivals takes into account all available users.
% (4) If the content is receiving from the eNB, the amount of received bits
%     are uploaded to the LiFi AP cache in the next TTI.
% (5) If the LiFi AP cache is full, the cached content will be evicted
%     based on least-frequently used (LFU) or
% (6) A content cannot be served by the LiFi AP if it has not fully
%     received.
%
% Created by Tezcan Cogalan, UoE, October 2019
%
clear all;clc
%% Describe system parameters
iterations = 1;
systemParameters = modifySystemParameters;
%% remove and modify them within modifysystemparameters.m
systemParameters.eNBonly = 0; % (=1) only eNB no LiFi; (=0) eNB + LiFi
systemParameters.numUserPerAP = 50;
systemParameters.poissonEventPerMin = 500;
systemParameters.poissonLambda = systemParameters.poissonEventPerMin/(60*1e3); % Poisson rate per millisecond; #X requests per 1 minute

%% Open Threads as required
% parpool(numberThreads);
%% Init output variables
eNBdataRate            = cell(iterations,1);
eNBinterference        = cell(iterations,1);
eNBSINROut             = cell(iterations,1);
eNBpowerConsumption    = cell(iterations,1);
eNBRBsUser             = cell(iterations,1);
eNBavgSINR             = cell(iterations,1);

LAPdataRate            = cell(iterations,1);
LAPinterference        = cell(iterations,1);
LAPSINROut             = cell(iterations,1);
LAPpowerConsumption    = cell(iterations,1);
LAPRBsUser             = cell(iterations,1);
LAPavgSINR             = cell(iterations,1);

GPP = [];
LP = [];
cch = [];

for i=1:iterations
    %% Initialize geometry
    [userLocations, APlocations, eNBlocations] = initGeometry(systemParameters);
    %% Generate channel and associate users to the AP/eNB/femtocell that has the highest gain for UE, LED, eNB initialization
    [UE, LED, eNB] = initUserAssociation(systemParameters,userLocations,APlocations,eNBlocations);
    %% Generate content's size, popularity
    [file] = ZipfContentPopularity(systemParameters.numFiles,systemParameters.ZipfParameter,systemParameters.bitsPerFile);
    % Initialize file set
    fileSet = 1:systemParameters.numFiles;
    % Obtain cumulative summation of the file popularity
    C = cumsum(file.popularity);
    
    %% Determine UE request arrivals and requested content
    fileName = sprintf('poissonEventData_%dperMin_%dminDuration.mat',systemParameters.poissonEventPerMin,systemParameters.simulationDuration);
    if exist(fileName)
        load(fileName)
    else
        % Generate user requests
        [eventTimeOrj, occurance] = poissonArrivals(systemParameters.poissonLambda,systemParameters.simulationDuration);
    %     eventTimeOrj = [eventTimeOrj(1).*ones(1,10), (eventTimeOrj(1)+30).*ones(1,5), (eventTimeOrj(1)+35).*ones(1,3)];
        eventTime = eventTimeOrj - [eventTimeOrj(1)-1].*ones(1,length(eventTimeOrj));
        %     pastEvents = [];
        save(fileName,'eventTime','eventTimeOrj','occurance')
    end
    %%
    totNumEvents = length(eventTime);
    remainingEvents = 1:totNumEvents;
    snr_db = -6:1:30;
    snr_r = 10.^(snr_db./10);
    
    %% Init variables
    eNBallocation          = cell(1, max(eventTime));
    eNBSINR                = cell(1, max(eventTime));
    eNBinterferenceOut     = cell(1, max(eventTime));
    eNBSINRTargets         = cell(1, max(eventTime));
    eNBbitsSymbol          = cell(1, max(eventTime));
    eNBtransmissionPower   = cell(1, max(eventTime));
    eNBscheduledUserOut    = cell(1, max(eventTime));
    eNBflaggedCHs          = cell(1, max(eventTime));
    eNBschedulingObjective = cell(1, max(eventTime));
    
    LAPallocation          = cell(1, max(eventTime));
    LAPSINR                = cell(1, max(eventTime));
    LAPinterferenceOut     = cell(1, max(eventTime));
    LAPSINRTargets         = cell(1, max(eventTime));
    LAPbitsSymbol          = cell(1, max(eventTime));
    LAPtransmissionPower   = cell(1, max(eventTime));
    LAPscheduledUserOut    = cell(1, max(eventTime));
    LAPflaggedCHs          = cell(1, max(eventTime));
    LAPschedulingObjective = cell(1, max(eventTime));
    
    % Initialize scheduling parameters
    totalUsers = length(UE.x);
    actualTTI = eventTime(1);
    
    %     UE.achievedRate = zeros(totalUsers,actualTTI);
    UE.eNBachievedRate = zeros(totalUsers,actualTTI);
    UE.LAPachievedRate = zeros(totalUsers,actualTTI);
    UE.requireResources = zeros(totalUsers,actualTTI);
    
    for b=1:systemParameters.numBS
        eNB.Smetric{b} = -Inf(1,length(eNB.connectedUE{b}));
    end
    
    for l=1:systemParameters.Nt
        LED.Smetric{b} = -Inf(1,length(LED.connectedUE{l}));
    end
    
    UE.activeBSs = zeros(1,totalUsers);
    UE.activeUsers_eNB = [];
    
    UE.activeLEDs = zeros(1,totalUsers);
    UE.activeUsers_LAP = [];
    
    % Initialize caching variables for LED
    LED.cachedFile          = zeros(systemParameters.Nt,systemParameters.numFiles);
    LED.requestedFileCount  = zeros(systemParameters.Nt,systemParameters.numFiles);
    LED.cacheHitRate        = zeros(systemParameters.Nt,1);
    LED.cacheMissRate       = zeros(systemParameters.Nt,1);
    LED.numEvent            = zeros(systemParameters.Nt,1);
    
    % Initialize caching variables for UE
    UE.requestTime          = -Inf.*ones(totalUsers,1);
    UE.servedTime           = -Inf.*ones(totalUsers,1);
    UE.rateBasedTT          = zeros(totalUsers,1);
    UE.latency              = cell(totalUsers,1);
    %     UE.fullyDownloadedFiles = cell(totalUsers,1);
    UE.selectedContent      = zeros(totalUsers,1);
    
    
    eNB.numEvent            = zeros(systemParameters.numBS,1);
    eNB.servedContent       = zeros(totalUsers,actualTTI);
    
%     figure;
    eventID = 0;
    flag = 0;
    while flag < 1
%         fprintf('Actual TTI %d \n', actualTTI)
        if exist('systemParameters.mobilityUpdatePeriod','var')
            if mod(actualTTI,systemParameters.mobilityUpdatePeriod) == 1
                %% Update user locations
                [userLocations, ~, ~] = initGeometry(systemParameters);
            end
        end
        %% Generate channel and associate users to the AP/eNB/femtocell that has the highest gain
        [UE, LED, eNB] = initUserAssociation_loopTTI(systemParameters,userLocations,UE,LED,eNB);
        %% Update LiFi AP cache status
        % It is assumed that the content downloaded at TTI t will be
        % fully uploaded to LiFi AP at TTI t+2
        if ismember(actualTTI-2,UE.servedTime) && size(eNB.servedContent,2) >= actualTTI-2 && systemParameters.eNBonly == 0
            LEDindex = unique(UE.connectedAP(logical(UE.servedTime==actualTTI-2)));
            [LED] = updateLiFiAPcache(LED,eNB,file,actualTTI,systemParameters.cacheSizeBits,LEDindex);
        end
        %% generate user arrival and content request when an arrival has occured
        if find(eventTime == actualTTI)
            eventID = eventID + 1;
            fprintf('Event ID %d \n', eventID);
            numMultipleEvents = length(find(eventTime(1)==eventTime));
            % Pick active users randomly
            %             userIndex = randsrc(1,numMultipleEvents,1:totalUsers);
            userIndex = randperm(totalUsers,numMultipleEvents);
            % An UE cannot request file if it is already scheduled - see rule (1).
            if ~isempty([UE.activeUsers_eNB, UE.activeUsers_LAP])
                nonActiveUEset = 1:totalUsers;
                nonActiveUEset(ismember(nonActiveUEset,[UE.activeUsers_eNB, UE.activeUsers_LAP])) = [];
                if length(nonActiveUEset) < numMultipleEvents
                    userIndex = nonActiveUEset;
                else
                    selectedSet = randperm(length(nonActiveUEset),numMultipleEvents);
                    userIndex = nonActiveUEset(selectedSet);
                end
            end
%             if ~isempty([UE.activeUsers_eNB, UE.activeUsers_LAP])
%                 counter_activeUserIndex = 0; % it is used to prevent unnecessarily long while loop
%                 while sum(ismember([UE.activeUsers_eNB, UE.activeUsers_LAP],userIndex))
%                     %                     userIndex = randsrc(1,1,1:totalUsers);
%                     userIndex = randperm(totalUsers,numMultipleEvents);
%                     userIndex = unique(userIndex);
%                     counter_activeUserIndex = counter_activeUserIndex+1;
%                     if counter_activeUserIndex > 10
%                         fprintf('Struggling to find a proper user index set\n');
%                     end
%                 end
%             end
            for usind=userIndex
                % Obtain its connected LiFi AP and eNB
                LEDindex = UE.connectedAP(usind);
                eNBindex = UE.connectedBS(usind);
                % Pick a content randomly based on Zipf distribution
                requestedContent = fileSet(1+sum(rand>C));
                % Record request time in order to use it for latency calculation
                % once the file is fully received.
                UE.requestTime(usind) = actualTTI;
                UE.enabled(usind) = 1;
                % Assign requested file size to the user
                UE.downloadedFileSize(usind) = 0;
                UE.downloadedFileSize_scheduler(usind) = 0;
                UE.selectedContentSize(usind) = file.sizeBits(requestedContent);
                % Assign this content to the user
                UE.selectedContent(usind) = requestedContent;
                % Increase number of event/arrivals for the AP
                LED.numEvent(LEDindex) = LED.numEvent(LEDindex)+1;
                % Check the file is cached at LiFi AP or not
                if LED.cachedFile(LEDindex,requestedContent) == 1 && systemParameters.eNBonly == 0
                    UE.activeLEDs(usind) = LEDindex;
%                     LED.queue = [LED.queue,usind];
                    LED.cacheHitRate(LEDindex) = LED.cacheHitRate(LEDindex) + 1;
                    LED.requestedFileCount(LEDindex,requestedContent) = LED.requestedFileCount(LEDindex,requestedContent)+1;
                    % Activate user
                    UE.activeUsers_LAP = [UE.activeUsers_LAP, usind];
                    LED.Smetric{LEDindex}(usind) = Inf;
                else % activate eNB
                    UE.activeBSs(usind) = eNBindex;
                    eNB.numEvent(eNBindex) = eNB.numEvent(eNBindex)+1;
                    LED.cacheMissRate(LEDindex) = LED.cacheMissRate(LEDindex)+1;
                    % Activate user
                    UE.activeUsers_eNB = [UE.activeUsers_eNB, usind];
                    eNB.Smetric{eNBindex}(usind) = Inf;
                end
            end
            %             pastEvents = [eventTime(1), pastEvents];
            eventTime(eventTime == eventTime(1)) = [];
        end
        %% Schedule active users - either at BS and/or AP based on cache availability
        if isempty([UE.activeUsers_eNB, UE.activeUsers_LAP])
            %% Decide to continue or terminate the simulation
            % If there is a forthcoming event, keep increasing TTI
            if actualTTI <= max(eventTime)
                actualTTI = actualTTI+1;
            else % if the max event time is reached and there is no active UE, break the WHILE LOOP
                flag = 1;
            end
        else
            %% schedule active users at BS
            if ~isempty(UE.activeUsers_eNB)
                WAT = 0;
                UE.eNBachievedRate(:,actualTTI) = zeros(totalUsers,1);
                eNBcurrentAllocationIN = zeros(systemParameters.numBS, systemParameters.eNBnumRBs);
                eNBSINRTargetIN        = repmat(-Inf, totalUsers, systemParameters.eNBnumRBs);
                eNBbitsSymbolIN        = zeros(totalUsers, systemParameters.eNBnumRBs);
                % Assume all eNBs transmit with full transmission power
                eNBsinrIN              = preComputeSINR(systemParameters,eNB.channelCoefficients,eNB,UE,WAT);
                if actualTTI == 1
                    eNBschedulingObjectiveIN = zeros(totalUsers,systemParameters.eNBnumRBs);
                else
                    if isempty(eNBschedulingObjective{actualTTI-1})
                        eNBschedulingObjectiveIN = zeros(totalUsers,systemParameters.eNBnumRBs);
                    else
                        eNBschedulingObjectiveIN = eNBschedulingObjective{actualTTI-1};
                    end
                end
                [eNBallocation{actualTTI}, eNBtransmissionPower{actualTTI}, eNBSINRTargets{actualTTI}, eNBbitsSymbol{actualTTI}, ...
                    UE, eNB, eNBschedulingObjective{actualTTI}] = proportionalFairScheduler(systemParameters, UE, eNB, ...
                    eNB.channelCoefficients, eNBcurrentAllocationIN, eNBSINRTargetIN, eNBbitsSymbolIN, eNBsinrIN, actualTTI, eNBschedulingObjectiveIN, WAT);
                % Calculate SINR - save values to carry next TTI, if necessary
                [eNBSINR{actualTTI},~,eNBinterferenceOut{actualTTI}] = calculateSINR(eNBallocation{actualTTI}, eNBtransmissionPower{actualTTI},...
                    eNB.channelCoefficients, eNB, UE, systemParameters, WAT);
                % Compute Performance
                UE.tempActiveUsers = UE.activeUsers_eNB;
                [eNBdataRate{i}{actualTTI}, eNBinterference{i}{actualTTI}, eNBSINROut{i}{actualTTI}, eNBSE{i}{actualTTI}, ...
                    eNBpowerConsumption{i}{actualTTI}, eNBRBsUser{i}{actualTTI}, eNBavgSINR{i}{actualTTI}] = ...
                    computePerformance(eNBSINR{actualTTI}, eNBallocation{actualTTI}, eNBSINRTargets{actualTTI}, eNBbitsSymbol{actualTTI},...
                    eNBinterferenceOut{actualTTI}, eNBtransmissionPower{actualTTI}, UE,eNB,systemParameters, WAT);
                %% Update status of active users
                [UE, eNB, LED] = updateStatus(UE, eNB, LED, actualTTI, eNBdataRate{i}, WAT);
                WAT = [];
            end
            
            %% schedule active users at LiFi AP
            if ~isempty(UE.activeUsers_LAP)
                WAT = 1;
                UE.LAPachievedRate(:,actualTTI) = zeros(totalUsers,1);
                LAPcurrentAllocationIN = zeros(systemParameters.numBS, systemParameters.LAPnumRBs);
                LAPSINRTargetIN        = repmat(-Inf, totalUsers, systemParameters.LAPnumRBs);
                LAPbitsSymbolIN        = zeros(totalUsers, systemParameters.LAPnumRBs);
                % Assume all eNBs transmit with full transmission power
                LAPsinrIN              = preComputeSINR(systemParameters,LED.channelCoefficients,LED,UE, WAT);
                if isempty(LAPschedulingObjective{actualTTI-1})
                    LAPschedulingObjectiveIN = zeros(totalUsers,systemParameters.LAPnumRBs);
                else
                    LAPschedulingObjectiveIN = LAPschedulingObjective{actualTTI-1};
                end
                [LAPallocation{actualTTI}, LAPtransmissionPower{actualTTI}, LAPSINRTargets{actualTTI}, LAPbitsSymbol{actualTTI}, ...
                    UE, LED, LAPschedulingObjective{actualTTI}] = proportionalFairScheduler(systemParameters, UE, LED, ...
                    LED.channelCoefficients, LAPcurrentAllocationIN, LAPSINRTargetIN, LAPbitsSymbolIN, LAPsinrIN, actualTTI, LAPschedulingObjectiveIN, WAT);
                % Calculate SINR - save values to carry next TTI, if necessary
                [LAPSINR{actualTTI},~,LAPinterferenceOut{actualTTI}] = calculateSINR(LAPallocation{actualTTI}, LAPtransmissionPower{actualTTI},...
                    LED.channelCoefficients, LED, UE, systemParameters, WAT);
                % Compute Performance
                UE.tempActiveUsers = UE.activeUsers_LAP;
                [LAPdataRate{i}{actualTTI}, LAPinterference{i}{actualTTI}, LAPSINROut{i}{actualTTI}, LAPSE{i}{actualTTI}, ...
                    LAPpowerConsumption{i}{actualTTI}, LAPRBsUser{i}{actualTTI}, LAPavgSINR{i}{actualTTI}] = ...
                    computePerformance(LAPSINR{actualTTI}, LAPallocation{actualTTI}, LAPSINRTargets{actualTTI}, LAPbitsSymbol{actualTTI},...
                    LAPinterferenceOut{actualTTI}, LAPtransmissionPower{actualTTI}, UE,LED,systemParameters, WAT);
                %% Update status of active users
                [UE, eNB, LED] = updateStatus(UE, eNB, LED, actualTTI, LAPdataRate{i}, WAT);
                WAT = [];
            end
            % Go to the next TTI
            actualTTI = actualTTI + 1;
        end
%         if actualTTI == 30
%             as=1;
%         elseif actualTTI == 35
%             as=2;
%         elseif actualTTI == 40
%             as=3;
%         end
%         realTimePlots
    end
end
save('UEdata_eNBLiFi','UE','eNB','LED','systemParameters')


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Update LiFi AP cache
% LED.cachedFile = zeros(systemParameters.Nt,systemParameters.numFiles);
% for t=1:systemParameters.Nt
%     % Find served content to the users that are connected to the
%     % LiFi AP t at TTI-2
%     servedContent = reshape(eNB.servedContent(LED.connectedUE{t},1:actualTTI-2),1,[]);
%     servedContent(servedContent==0) = [];
%     servedContent = unique(servedContent);
%     % Obtain popularity of the served content
%     for c=1:length(servedContent)
%         popi(c) = sum(logical(servedContent==servedContent(c)));
%     end
%     [sortedPopi,popiIndex] = sort(popi,'descend');
%     for f=popiIndex
%         alreadyCachedContent = logical(LED.cachedFile(t,:)>0);
%         cacheFilledSpace = sum(file.sizeBits(alreadyCachedContent));
%         cacheFreeSpace = systemParameters.cacheSizeBits - cacheFilledSpace;
%         if ( cacheFreeSpace >= file.sizeBits(f) )
%             LED.cachedFile(t,f) = 1;
%         end
%     end
% end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Randomly assign an achievable rate to the user
% UEsnr_r = randsrc(1,1,snr_r);
% [UEsnr_db,perRBrate] = modulationTable(UEsnr_r);
% UE(userIndex).SNRdB = [UEsnr_db, UE(userIndex).SNRdB];
% % Obtain how long does it take to send the content if there is no any other active user
% % present in the system at the given time - convert the rate from s to ms
% rateAllRBs = (perRBrate.*systemParameters.symbolsTS./...
%     systemParameters.TSduration.*systemParameters.subcarriersPerResource.*...
%     systemParameters.eNBnumRBs);
% transmissionTime = ceil(file.sizeBits(requestedContent)./rateAllRBs.*1e3);
% UE(userIndex).rateBasedTT = [transmissionTime, UE(userIndex).rateBasedTT];
% % Flag BS as busy during the transmission time in order to handle
% % scheduling - if any other user requests service
% BSqueue(userIndex,actualTTI:actualTTI+transmissionTime+1) = 1;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%             for bs=eNB.activeBSs
%                 activeUsers = eNB.connectedUE{bs}(ismember(eNB.connectedUE{bs},eNB.queue));
%                 numActiveUsers = length(activeUsers);
%                 [~,~,interference] = calculateSINR_eNB(
%                 for u=activeUsers
%                     % Obtain interference power
%                     [~,~,interference] = calculateSINR_eNB(
%                     UEsnr_r = randsrc(1,1,snr_r);
%                     [UEsnr_db,perRBrate] = modulationTable(UEsnr_r);
%                     UE(u).SNRdB = [UEsnr_db, UE(u).SNRdB];
%                     % Obtain how long does it take to send the content if there is no any other active user
%                     % present in the system at the given time - convert the rate from s to ms
%                     rateAllRBs(u) = (perRBrate.*systemParameters.symbolsTS./...
%                         systemParameters.TSduration.*systemParameters.subcarriersPerResource.*...
%                         systemParameters.eNBnumRBs);
%                     neededRBs(u) = rateAllRBs(u)/systemParameters.eNBnumRBs;
%                     % transmission time in case of no user present
%                     transmissionTime(u) = ceil(file.sizeBits(UE(u).requestedFile(1))./...
%                         (rateAllRBs(u).*systemParameters.eNBnumRBs).*1e3);
%                     UE(u).rateBasedTT = [transmissionTime(u), UE(u).rateBasedTT];
%                     clear UEsnr_r UEsnr_db perRBrate
%                 end
%                 % schedule users - downlink
%                 if systemParameters.scheduler == 1 % PF
%
%
%                 end
%             end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


function [UE, LED, eNB] = initUserAssociation(systemParameters,userLocations,APlocations,eNBlocations)

% Create structure for UE
% UE structure is created along with the channel gain generation in order
% to prevent using an extra for loop

% Create structure for APs
% for t=1:systemParameters.Nt
%     LED(t).location         = []; % location of the AP
%     LED(t).incA             = []; % incidence angle from each UE
%     LED(t).divA             = []; % divergence angle to each UE
%     LED(t).distance         = []; % distance between the AP and each UE
%     LED(t).Rect             = []; % output of the rect function for each UE
%     LED(t).H                = []; % channel gain of each UE
%     LED(t).connectedUE      = []; % connected UE to the AP
%     LED(t).scheduledUE      = []; % scheduled UE at a given time t at the AP
%     LED(t).cachedFile       = []; % cached file list at the AP
%     LED(t).requestedFile    = []; % list of requested content at the AP, can be used to decide content eviction
%     LED(t).UEarrivalOrder   = []; % lists UE arrivals
%     LED(t).numEvent         = []; % number of events/arrivals for the AP
%     LED(t).eventTime        = []; % event/arrival time to the AP
%     LED(t).occurance        = []; % Occurance time difference between adj. events
%     LED(t).cacheHitRate     = []; % increases if the requested content is in the AP cache
%     LED(t).cacheMissRate    = []; % increases if the requested content is not in the AP cache
%     LED(t).remainingEvents  = []; % list of remaining events
%     LED(t).activeUsers      = []; % list of users waiting to be served or still serving by the AP
%     % LED's cache size
%     LED(t).cacheSize        = systemParameters.cacheSizeBits;
%     % LED's active time - can be used to obtain SINR for a given time t
%     LED(t).activeTime       = zeros(1,systemParameters.simulationDuration);
% end

%%
% Free-space path loss at reference distance d0=1m for 1.8 GHz
FSPL = 37.5; % [dB]
stdFastFading = 10^(systemParameters.stdFastFading/10);
meanFastFading = 10^(systemParameters.meanFastFading/10);

totalUsers = size(userLocations,1);

UE.connectedBS  = zeros(1,totalUsers);
UE.connectedAP  = zeros(1,totalUsers);
UE.enabled      = zeros(1,totalUsers);
UE.allocatedRBs = cell(1,totalUsers);
UE.activeUsers  = [];
eNB.allowedRBs  = ones(systemParameters.numBS,systemParameters.eNBnumRBs);
LED.allowedRBs  = ones(systemParameters.Nt   ,systemParameters.LAPnumRBs);
%% Initialize connected UE in the eNB and LED structures
eNB.connectedUE = cell(1,systemParameters.numBS);
LED.connectedUE = cell(1,systemParameters.Nt);

for u=1:totalUsers
    % Create structure for UE
    %     UE(u).connectedAP = [];
    %     UE(u).connectedBS = [];
    %     UE(u).requestedFile = [];
    %     UE(u).requestTime = [];
    %     UE(u).servedTime = [];
    %     UE(u).latency   = [];
    %     UE(u).SNRdB = [];
    %     UE(u).rateBasedTT = []; % rate based transmission time
    %     UE(u).achievedRate = [];
    %     UE(u).allChGain = zeros(systemParameters.Nt,1);
    
    
    UE.x(u) = userLocations(u,1);
    UE.y(u) = userLocations(u,2);
    UE.z(u) = userLocations(u,3);
    
    %% Assign UE to BS/femtocell
    for bs = 1:systemParameters.numBS
        eNB.x(bs) = eNBlocations(bs,1);
        eNB.y(bs) = eNBlocations(bs,2);
        eNB.z(bs) = eNBlocations(bs,3);
        [~,~,eNB.distance(bs,u)] = calculateAngle(zeros(1,3),zeros(1,3),eNBlocations(bs,:),userLocations(u,:));
        % Associate UE u to the AP that has the highest channel gain
        [minDistanceValue(u),minDistanceBSindex] = min(eNB.distance(:,u));
        pathLoss(bs,u) = FSPL + 10*systemParameters.alpha_n*log10(eNB.distance(bs,u)) + (systemParameters.sigma_L)*randn;
        overallPL = -pathLoss(bs,u) + ((stdFastFading)*randn(1,systemParameters.eNBnumRBs)+meanFastFading);
        eNB.channelCoefficients(u,bs,:) = 10.^(overallPL./10);
        % Check the gain is not same with any other AP, if it is, randomly
        % allocate
        minValsIndex = find(eNB.distance(:,u)==minDistanceValue(u));
        selectedBS = randsrc(1,1,minValsIndex');
        UE.connectedBS(u) = selectedBS;
        eNB.connectedUE{selectedBS} = [eNB.connectedUE{selectedBS}, u];
    end
    
    
    for t=1:systemParameters.Nt
        LED.x(t) = APlocations(t,1);
        LED.y(t) = APlocations(t,2);
        LED.z(t) = APlocations(t,3);
        
        [LED.incA(t,u),LED.divA(t,u),LED.distance(t,u)]=...
            calculateAngle(systemParameters.LEDdirection,systemParameters.PDdirection,APlocations(t,:),userLocations(u,:));
        [LED.Rect(t,u),~] = rect(LED.incA(t,u),systemParameters.RxFOV,1,[]);
        if LED.divA(t,u) > 90
            LED.H(u,t) = 0;
        else
            LED.H(u,t) = systemParameters.optFilterGain*systemParameters.ConcentratorGain*...
                (systemParameters.LambOrder+1)*...
                cosd(LED.divA(t,u))^(systemParameters.LambOrder)...
                *cosd(LED.incA(t,u))*LED.Rect(t,u)*systemParameters.Area_eff/(2*pi*(LED.distance(t,u)^2));
        end
        % In order to be able to use functions written for eNB, channel
        % gain/coefficients should have the same size
        LED.channelCoefficients(u,t,:) = repmat(LED.H(u,t),1,1,systemParameters.LAPnumRBs);
        H_NtLEDs(1,t) = LED.H(u,t);
    end
    UE.allChGain(u,:) = H_NtLEDs;
    
    % Associate UE u to the AP that has the highest channel gain
    [maxChGainValue(u),maxChGainAPindex] = max(UE.allChGain(u,:));
    if maxChGainValue(u) == 0
        asd=1;
        continue
    else
        % Check the gain is not same with any other AP, if it is, randomly
        % allocate
        maxValsIndex = find(UE.allChGain(u,:)==maxChGainValue(u));
        selectedAP = randsrc(1,1,maxValsIndex');
        UE.connectedAP(u) = selectedAP;
        LED.connectedUE{selectedAP} = [LED.connectedUE{selectedAP}, u];
        
        % Plot line to clearly see the connected users
        plot([LED.x(selectedAP),UE.x(u)],[LED.y(selectedAP),UE.y(u)],'k-','HandleVisibility','off')
        drawnow
    end
end

%% Init BS affinity
UE.allocatedRBs = cell(1,length(UE.x));

% %% Init QoS Requirements
% UE.userRate = zeros(1,length(UE.x));






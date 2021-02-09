function [allocation, SINRTargets, bitsSymbol, BSs, MSs, schedulingObjective] = PFS(simParams, BSs, MSs, currentSINR, ...
    schedulingObjective, RBlist, allocation, SINRTargets, bitsSymbol, TTIindex, flaggedCHs, WAT)
% This function allocated RBs based on proportional fair scheduling.
% It supports theoretical RA and LTE RA Type 0
%
% Written by Tezcan Cogalan, UoE, November 2016
%
% Update - 10/10/2019
% The following part needs to be changed to consider remaining file size
% and achieved data rate (how much of the file has downloaded, and see is
% there any remaining bits/parts for the content/file.
% -- OLD Version
% if ~isempty(bestScheduledUser)
%    if ( 1/BSs.Smetric{bestConnectedBS}(ueind) ) >= simParams.dataRateFairnessThreshold
%
% -- NEW Version
% if ~isempty(bestScheduledUser)
%   if ( MSs.downloadFileSize_scheduler(ueind) >= MSs.selectedContentSize(ueind) )
%
% Update - 05/11/2019
% The scheduling process should be apply only to the active eNBs - which
% will be determined based on the active users, in other words, based on
% poisson arrivals. 
% Therefore, the following lines in the old code should be modified 
% 1) " consideredBSs = find(BSs.allowedRBs(:,j)>0)' " at line 39 - old code
% 2) " candidateUsers = find(max(tempSchedulingObjective(:,j)) == tempSchedulingObjective(:,j)) " at line 48 - old code
% 
% Update - 07/11/2019
% A parameter is needed to decide when the download time should be
% recorded.
%
% Update - 29/11/2019
% Parameter "WAT" is added to decide wireless access technology when UE
% related information is checked/updated - for example: connected BS or
% LiFi AP or WiFi AP
% WAT = 0 -> eNB
% WAT = 1 -> LiFi AP
%
% Update - 25/03/2020
% Achieved rate is calculated as bit per second and it needs to be
% converted to bit per millisecond level in order to obtain rate per TTI of
% 1 ms level. Therefore, MSs.downloadFileSize_scheduler is updated in each
% TTI with RBsInRBG*instantRate(bestScheduledUser)./1e3 bits.


%% Init variables
% bestScheduledUser   = zeros(1,simParams.numberRBs);
% bestConnectedBS     = zeros(1,simParams.numberRBs);

%% Allocate
for jj = randperm(length(RBlist)-1)
    % Find the actual index of the RB
    j = RBlist(jj);
    % Find number of RBs in a RB group, it is going to be used in instant rate calculation where rate of an RB will be multiplied with number of RBs in RBG
%     if jj == length(RBlist)
%         RBsInRBG = max(RBlist) - j;
%     else
        RBsInRBG = RBlist(jj+1) - RBlist(jj);
%     end
    % Allocate RB j on each BS where RB j is allowed
    allowedBSs = find(BSs.allowedRBs(:,j)>0)';
    % Consider only the active eNBs - update on 05/11/2019
    if WAT == 0
        bsindexes = ismember( allowedBSs, unique(MSs.activeBSs(MSs.activeBSs > 0)) );
    elseif WAT == 1
        bsindexes = ismember( allowedBSs, unique(MSs.activeLEDs(MSs.activeLEDs > 0)) );
    end
    if isempty(allowedBSs(bsindexes))
        error('There is no active eNB that can use the RB j');
    else
        consideredBSs = allowedBSs(bsindexes);
    end
    tempSchedulingObjective = schedulingObjective;
    while ~isempty(consideredBSs)
        % Find the users who maximizes the scheduling objective and haven't
        % achieved the data rate fairness threshold yet
        bestScheduledUser = [];
        bestConnectedBS = [];
        if WAT == 0
            activeUsersSchedulingObjective = tempSchedulingObjective(MSs.activeUsers_eNB,j);
            if activeUsersSchedulingObjective == -Inf
                break
            else
                activeCandidateUsers = find(max(activeUsersSchedulingObjective) == activeUsersSchedulingObjective);
                candidateUsers = MSs.activeUsers_eNB(activeCandidateUsers);
            end
        elseif WAT == 1
            activeUsersSchedulingObjective = tempSchedulingObjective(MSs.activeUsers_LAP,j);
            if activeUsersSchedulingObjective == -Inf
                break
            else
                activeCandidateUsers = find(max(activeUsersSchedulingObjective) == activeUsersSchedulingObjective);
                candidateUsers = MSs.activeUsers_LAP(activeCandidateUsers);
            end
        end
%         candidateUsers = find(max(tempSchedulingObjective(:,j)) == tempSchedulingObjective(:,j));
        [bestScheduledUser, bestConnectedBS] = findScheduledUser(candidateUsers,MSs,WAT);
        ueind = logical(BSs.connectedUE{bestConnectedBS} == bestScheduledUser);
        if ~isempty(bestScheduledUser)
            if ( MSs.downloadedFileSize_scheduler(bestScheduledUser) >= MSs.selectedContentSize(bestScheduledUser) )
                % if computePerformance.m is activated, record latency and
                % caching data. Then deactivate user.
                    %             if ( 1/BSs.Smetric{bestConnectedBS}(ueind) ) >= simParams.dataRateFairnessThreshold
                % Find another user who hasn't achieved the threshold data rate yet
                tempSchedulingObjective(bestScheduledUser,j) = -Inf;
                if sum(tempSchedulingObjective(:,j)>0) == 0
                    break % leave RB unallocated
                end
            else
                % Check RB j is available
                if allocation(bestConnectedBS,j) == 0
                    % Check rate on RB j for user bestScheduledUser is meaningful to allocate
                    if bitsSymbol(bestScheduledUser,j) > 0
                        % Allocate
                        allocation(bestConnectedBS,j:j+RBsInRBG-1) = bestScheduledUser;
                        % Calculate rate and update user scheduling metric BSs.Smetric
                        [instantRate, MSs, BSs] = calculateRate(MSs, BSs, bestScheduledUser, currentSINR, ...
                            SINRTargets, bitsSymbol, simParams, TTIindex, bestConnectedBS, j, RBsInRBG, WAT);
                        % Update downloaded file size for the user - rate
                        % is calculated as bps and it is converted to bpms
                        % level in order to mimic TTI level of 1ms
                        MSs.downloadedFileSize_scheduler(bestScheduledUser) = MSs.downloadedFileSize_scheduler(bestScheduledUser) + RBsInRBG*instantRate(bestScheduledUser)./1e3;
                        % Update scheduling objective
                        [schedulingObjective, SINRTargets, bitsSymbol] = calculateSchedulingObjective(simParams, BSs, MSs, currentSINR, ...
                            bestScheduledUser, 1, schedulingObjective, SINRTargets, bitsSymbol, flaggedCHs, WAT);
                        % Remove connected BS from the considered BS list
                        consideredBSs(consideredBSs == bestConnectedBS) = [];
                        tempSchedulingObjective(BSs.connectedUE{bestConnectedBS},j) = -Inf;
                    else
                        % Discard the user for RB j, if the rate is 0
                        tempSchedulingObjective(bestScheduledUser,j) = -Inf;
                    end
                else
                    % IF the RB j at bestConnectedBS is already allocated, discard the BS
                    consideredBSs(consideredBSs == bestConnectedBS) = [];
                    tempSchedulingObjective(BSs.connectedUE{bestConnectedBS},j) = -Inf;
                end
            end
        else
            break % leave RB unallocated
        end
    end
end
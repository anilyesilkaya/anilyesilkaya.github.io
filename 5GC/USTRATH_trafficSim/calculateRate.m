function [instantRate, MSs, BSs] = calculateRate(MSs, BSs, scheduledUser, currentSINR, ...
            SINRTargets, bitsSymbol, simParams, TTIindex, BSindex, RBIndex, RBsInRBG, WAT)
% This function determines achieved rate by the scheduled user and updates
% scheduling metric and required resource situation of the users
%
% Written by Tezcan Cogalan, UoE, 06/10/2016
%
% Update - 11/03/2020 | #1
% The user satisfaction will be based on the downloaded content - is the
% requested content fully downloaded or not.
% -- OLD Version - Airbus data rate per user QoS requirement
% sum(MSs.achievedRate(scheduledUser,:)) >= MSs.userRate(scheduledUser)
%
% -- New Version - Content download size based
% MSs.downloadedFileSize_scheduler(bestScheduledUser) >= MSs.selectedContentSize(bestScheduledUser)
%
% Update - 11/03/2020 | #2
% MSs.achievedRate is a #user-by-TTI matrix and it is used to obtain
% scheduling metric (e.g. proportional fair). Therefore, it should be
% WAT-specific. Accordingly, 
% (1)  MSs.achievedRate is considered as the total achieved rate of a user
% that includes any type of active WAT.
% (2)  MSs.eNBachievedRate is used for 3GPP technologies - 4G/5G.
% (3)  MSs.LAPachievedRate is used for LiFi.
%
%
%% Calculate achieved instant data rate for the scheduled user
if WAT == 0
    instantRate(scheduledUser) = ...
    sum((currentSINR(scheduledUser,RBIndex) > 10.^(SINRTargets(scheduledUser,RBIndex)./10)-1.0233)...
    .*bitsSymbol(scheduledUser,RBIndex))...
    .*simParams.symbolsTS./simParams.TSduration.*simParams.subcarriersPerResource;
    MSs.eNBachievedRate(scheduledUser,TTIindex) = MSs.eNBachievedRate(scheduledUser,TTIindex) + RBsInRBG*instantRate(scheduledUser);
elseif WAT == 1
    instantRate(scheduledUser) = ...
    sum((currentSINR(scheduledUser,RBIndex) > 10.^(SINRTargets(scheduledUser,RBIndex)./10)-1.0233)...
    .*bitsSymbol(scheduledUser,RBIndex))...
    .*simParams.LAPsymbolsTS./simParams.LAPTSduration.*simParams.LAPsubcarriersPerResource;
    MSs.LAPachievedRate(scheduledUser,TTIindex) = MSs.LAPachievedRate(scheduledUser,TTIindex) + RBsInRBG*instantRate(scheduledUser);
end
%% Calculate the total achieved rate by the scheduled user
% MSs.achievedRate(scheduledUser,TTIindex) = MSs.eNBachievedRate(scheduledUser,TTIindex) + MSs.LAPachievedRate(scheduledUser,TTIindex);
%% If the scheduled user satisfied / unsatisfied
% if sum(MSs.achievedRate(scheduledUser,:)) >= MSs.userRate(scheduledUser),
if MSs.downloadedFileSize_scheduler(scheduledUser) >= MSs.selectedContentSize(scheduledUser)
    % Set its PF metric to minimum
    MSs.requireResources(scheduledUser) = 0;
    BSs.Smetric{BSindex}(BSs.connectedUE{BSindex}==scheduledUser) = -Inf;
    if WAT == 0
        MSs.activeUsers_eNB(MSs.activeUsers_eNB==scheduledUser) = [];
    elseif WAT == 1
        MSs.activeUsers_LAP(MSs.activeUsers_LAP==scheduledUser) = [];
    end
else % if the scheduled user unsatisfied
    % Require resource blocks
    MSs.requireResources(scheduledUser) = 1;
    if isfield(MSs,'lastTimeScheduled') && simParams.scheduler == 7 % PCS
        MSs.lastTimeScheduled(scheduledUser) = -1;
    end
    % Calculate PF metric after allocating the RBs
    for bs=1:length(BSs.x)
        if simParams.averagingPeriod == 1 % infinite buffer
            if WAT == 0
                BSs.Smetric{bs} = 1./sum(MSs.eNBachievedRate(BSs.connectedUE{bs},:),2);
            elseif WAT == 1
                BSs.Smetric{bs} = 1./sum(MSs.LAPachievedRate(BSs.connectedUE{bs},:),2);
            end
        else % window based finite buffer, only averages the latest simParams.averagingPeriod TTIs 
            if TTIindex < simParams.averagingPeriod % prevent any matrix element mismatch due to TTIndex-averagingPeriod, it will be < 0 until TTIindex==averagingPeriod
                if WAT == 0
                    periodRate = sum(MSs.eNBachievedRate(BSs.connectedUE{bs},1:TTIindex),2);
                elseif WAT == 1
                    periodRate = sum(MSs.LAPachievedRate(BSs.connectedUE{bs},1:TTIindex),2);
                end
            else
                if WAT == 0
                    periodRate = sum(MSs.eNBachievedRate(BSs.connectedUE{bs},TTIindex-simParams.averagingPeriod+1:TTIindex),2);
                elseif WAT == 1
                    periodRate = sum(MSs.LAPachievedRate(BSs.connectedUE{bs},TTIindex-simParams.averagingPeriod+1:TTIindex),2);
                end
            end
            if WAT == 0
                BSs.Smetric{bs}(MSs.activeUsers_eNB) = 1 ./ (periodRate(MSs.activeUsers_eNB)./simParams.averagingPeriod);
            elseif WAT == 0
                BSs.Smetric{bs}(MSs.activeUsers_LAP) = 1 ./ (periodRate(MSs.activeUsers_LAP)./simParams.averagingPeriod);
            end
        end
    end
end
% BSs.Smetric{1};
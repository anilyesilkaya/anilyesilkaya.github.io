function [schedulingObjective, SINRTargets, bitsSymbol] = calculateSchedulingObjective(simParams, BSs, MSs, currentSINR, ...
    scheduledUser, computationType, schedulingObjective, SINRTargets, bitsSymbol, flaggedCHs, WAT)
% This function calculates the proportional fair scheduling objective S as follows:
% w_u       : scheduling metric (weight) of user u - BSs.Smetric
% r_(u,n)   : achievable rate on RB n for user u
% S_(u,n)   : scheduling objective
%
% S_(u,n) = w_u .* r_(u,n)
% 
% Scheduling decision will be taken by
% x_(u,n) = 1 if u:= argmax_u [ S_(u,n) ]
%
% Written by Tezcan Cogalan, UoE, 06/10/2016
%
% Update - 29/11/2019
% Parameter "WAT" is added to decide wireless access technology when UE
% related information is checked/updated - for example: connected BS or
% LiFi AP or WiFi AP
% WAT = 0 -> eNB
% WAT = 1 -> LiFi AP
%
% Update - 24/12/2019
% Achievable rate calculation is updated for LiFi
% WAT parameter is also used as an input for CQIreport function for IEEE
% 802.11ax based modulation table.
%
%
% If it is for pre-computation, compute it for all users
if computationType == 0
%     figure; hold on;
    for i = 1:length(MSs.x)
        if WAT == 0
            % Determine SINRTargets and bitsSymbol for user i
            [SINRTargets(i,:), bitsSymbol(i,:)] = CQIreport(simParams, BSs.allowedRBs(MSs.connectedBS(i),:), currentSINR(i,:), flaggedCHs(MSs.connectedBS(i)),WAT);
%             plot(10.*log10(currentSINR(i,:)),'DisplayName',sprintf('%d',i));
            % Determine achievable rate on each RB for user i
            achievableRate(i,:) = bitsSymbol(i,:).*simParams.symbolsTS./simParams.TSduration.*simParams.subcarriersPerResource;
            % Find index of user i in the BSs.connectedMS
            userInd = logical(BSs.connectedUE{MSs.connectedBS(i)} == i);
            % Compute scheduling objective values
            schedulingObjective(i,:) = BSs.Smetric{MSs.connectedBS(i)}(userInd).*achievableRate(i,:);
        elseif WAT == 1
            % Determine SINRTargets and bitsSymbol for user i
            [SINRTargets(i,:), bitsSymbol(i,:)] = CQIreport(simParams, BSs.allowedRBs(MSs.connectedAP(i),:), currentSINR(i,:), flaggedCHs(MSs.connectedAP(i)),WAT);
            % Determine achievable rate on each RB for user i
            achievableRate(i,:) = bitsSymbol(i,:).*simParams.LAPsymbolsTS./simParams.LAPTSduration.*simParams.LAPsubcarriersPerResource;
            % Find index of user i in the BSs.connectedMS
            userInd = logical(BSs.connectedUE{MSs.connectedAP(i)} == i);
            % Compute scheduling objective values
            schedulingObjective(i,:) = BSs.Smetric{MSs.connectedAP(i)}(userInd).*achievableRate(i,:);
        end
        % Assign -Inf to NaN values
        schedulingObjective(i,(isnan(schedulingObjective(i,:)))) = -Inf;
    end
    hold off;
else % otherwise, just compute objective of the scheduled user
    i = scheduledUser;
    % Determine SINRTargets and bitsSymbol for user i
    if WAT == 0
        [SINRTargets(i,:), bitsSymbol(i,:)] = CQIreport(simParams, BSs.allowedRBs(MSs.connectedBS(i),:), currentSINR(i,:), flaggedCHs(MSs.connectedBS(i)),WAT);
        % Determine achievable rate on each RB for user i
        achievableRate(i,:) = bitsSymbol(i,:).*simParams.symbolsTS./simParams.TSduration.*simParams.subcarriersPerResource;
        % Find index of user i in the BSs.connectedMS
        userInd = logical(BSs.connectedUE{MSs.connectedBS(i)} == i);
        % Compute scheduling objective values
        schedulingObjective(i,:) = BSs.Smetric{MSs.connectedBS(i)}(userInd).*achievableRate(i,:);
    elseif WAT == 1
        [SINRTargets(i,:), bitsSymbol(i,:)] = CQIreport(simParams, BSs.allowedRBs(MSs.connectedAP(i),:), currentSINR(i,:), flaggedCHs(MSs.connectedAP(i)),WAT);
        % Determine achievable rate on each RB for user i
        achievableRate(i,:) = bitsSymbol(i,:).*simParams.LAPsymbolsTS./simParams.LAPTSduration.*simParams.LAPsubcarriersPerResource;
        % Find index of user i in the BSs.connectedMS
        userInd = logical(BSs.connectedUE{MSs.connectedAP(i)} == i); 
        % Compute scheduling objective values
        schedulingObjective(i,:) = BSs.Smetric{MSs.connectedAP(i)}(userInd).*achievableRate(i,:);
    end
    % Assign -Inf to NaN values
    schedulingObjective(i,(isnan(schedulingObjective(i,:)))) = -Inf;
end
% schedulingObjective;
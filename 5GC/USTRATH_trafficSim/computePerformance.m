function [dataRate, interferenceOut, SINROut, SE, powerConsumption, RBsUser, avgSINR] = computePerformance(SINR, allocation, SINRTargets, bitsSymbol, interference, ...
    transmissionPower, MSs, BSs, systemParameters, WAT)
% Computes the dataRate per user as well as stores the interference
% received
%
% Created by Stefan Videv, 11/14/2013
%
% Update - 29/11/2019
% Parameter "WAT" is added to decide wireless access technology when UE
% related information is checked/updated - for example: connected BS or
% LiFi AP or WiFi AP
% WAT = 0 -> eNB
% WAT = 1 -> LiFi AP


%% Initialize
dataRate = zeros(1,length(MSs.x));
interferenceOut = cell(1,length(MSs.x));
SINROut = cell(1,length(MSs.x));
SE = zeros(1, length(MSs.x));
powerConsumption = zeros(1, length(BSs.x));
RBsUser = zeros(1,length(MSs.x));
avgSINR = cell(1,length(MSs.x));

SINRTargets = 10.^(SINRTargets./10);
for i = MSs.tempActiveUsers,
    % Find allocated RBs
    if WAT == 0
        allocatedRBs = allocation(MSs.connectedBS(i),:) == i;
    elseif WAT == 1
        allocatedRBs = allocation(MSs.connectedAP(i),:) == i;
    end
    %% Compute data rate
    linkSINR = SINR(i,allocatedRBs);
    if WAT == 0
        dataRate(i) = dataRate(i) + sum((linkSINR > SINRTargets(i,allocatedRBs)-1.0233).*bitsSymbol(i,allocatedRBs)).*systemParameters.symbolsTS...
            ./systemParameters.TSduration.*systemParameters.subcarriersPerResource;
    elseif WAT == 1
        dataRate(i) = dataRate(i) + sum((linkSINR > SINRTargets(i,allocatedRBs)-1.0233).*bitsSymbol(i,allocatedRBs)).*systemParameters.LAPsymbolsTS...
            ./systemParameters.LAPTSduration.*systemParameters.LAPsubcarriersPerResource;
    end
%     if (dataRate(i)==0 && sum(allocatedRBs)>0)
%         keyboard;
%     end
    %% Compute interference
    interferenceOut{i} =interference(i,allocatedRBs);
    %% Save SINR information
    SINROut{i} = SINR(i,allocatedRBs);
    %% Get average SINR of each user based on allocated RBs
    avgSINR{i} = mean(SINROut{i});
    %% Compute Average Spectral efficiency
    SE(i) = sum(log2(1+SINR(i,allocatedRBs)))/sum(allocatedRBs);
    %% Compute number of RBs per user
    RBsUser(i) = sum(allocatedRBs);
end

for i = 1:length(BSs.x),
    powerConsumption(i) = sum(transmissionPower(i,allocation(i,:)>0));
end
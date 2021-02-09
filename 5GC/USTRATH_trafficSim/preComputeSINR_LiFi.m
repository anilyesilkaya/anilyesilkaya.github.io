function currentSINR = preComputeSINR_LiFi(simParams,channelCoefficients,noiseFloor,BSs,MSs)
% This function computes SINR to consider in the allocation process.
% It assumes all eNBs use full transmission power on their allowed RBs
%
% INPUT:
%       simParams           : considered simualtion parameters
%       channelCoefficients : channel coefficient of each RB from eNB to user
%       noiseFloor          : considered noise floor value
%       BSs                 : eNBs struct
%       MSs                 : Users struct
% OUTPUT:
%       currentSINR         : computed SINR of each user when the full transmission power is used in each eNB
%
% Written by Tezcan Cogalan, UoE, 06/10/2016

%% Initialize Variables
currentSINR         = zeros(length(MSs.x), simParams.LAPnumRBs);
allRBsSINR          = zeros(length(MSs.x), simParams.LAPnumRBs);
transmissionPower   = zeros(length(BSs.x), simParams.LAPnumRBs);
allocation          = zeros(length(BSs.x),simParams.LAPnumRBs);
%% Pre-compute transmission power
% Compute maximum transmission power of each eNB based on their bandwidth
maxTransmitPower = 10^((simParams.LAPPower-30)/10)./sum(BSs.allowedRBs,2).*simParams.powerMultFactor;
for b = 1:length(BSs.x)
    % Determine useable RBs at the BS
    allowedRBs{b} = find(BSs.allowedRBs(b,:)>0);
    % Set the maximum transmission power on each RB
    transmissionPower(b,allowedRBs{b}) = maxTransmitPower(b);
end

%% Compute interference under the assumption of using full transmission power at all eNBs
[~,~,interference] = calculateSINR_LiFi(allocation, transmissionPower, channelCoefficients, noiseFloor, BSs, MSs, simParams);

%% Compute SINR
for i = MSs.activeUsers,
    % Calculate SINR based on computed interference
    allRBsSINR(i,:) = abs(sqrt(maxTransmitPower(MSs.connectedAP(i)))...
        .*reshape(channelCoefficients(i,MSs.connectedAP(i),:),1,[])).^2 ./ interference(i,:);
    % Carry SINR of user i on the allowed RBs
    currentSINR(i,allowedRBs{MSs.connectedAP(i)}) = allRBsSINR(i,allowedRBs{MSs.connectedAP(i)});  
end
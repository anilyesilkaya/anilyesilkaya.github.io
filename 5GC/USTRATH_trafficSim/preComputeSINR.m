function currentSINR = preComputeSINR(simParams,channelCoefficients,BSs,MSs, WAT)
% This function computes SINR to consider in the allocation process.
% It assumes all eNBs use full transmission power on their allowed RBs
%
% INPUT:
%       simParams           : considered simualtion parameters
%       channelCoefficients : channel coefficient of each RB from eNB to user
%       BSs                 : eNBs struct
%       MSs                 : Users struct
% OUTPUT:
%       currentSINR         : computed SINR of each user when the full transmission power is used in each eNB
%
% Written by Tezcan Cogalan, UoE, 06/10/2016
%
% Update - 29/11/2019
% Parameter "WAT" is added to decide wireless access technology when UE
% related information is checked/updated - for example: connected BS or
% LiFi AP or WiFi AP
% WAT = 0 -> eNB
% WAT = 1 -> LiFi AP


%% Initialize Variables
if WAT == 0
    currentSINR         = zeros(length(MSs.x), simParams.eNBnumRBs);
    allRBsSINR          = zeros(length(MSs.x), simParams.eNBnumRBs);
    transmissionPower   = zeros(length(BSs.x), simParams.eNBnumRBs);
    allocation          = ones(length(BSs.x), simParams.eNBnumRBs);
elseif WAT == 1
    currentSINR         = zeros(length(MSs.x), simParams.LAPnumRBs);
    allRBsSINR          = zeros(length(MSs.x), simParams.LAPnumRBs);
    transmissionPower   = zeros(length(BSs.x), simParams.LAPnumRBs);
    allocation          = ones(length(BSs.x), simParams.LAPnumRBs);
end
%% Pre-compute transmission power
if WAT == 0 % eNB
    % Compute maximum transmission power of each eNB based on their bandwidth
    maxTransmitPower = 10^((simParams.BSPower-30)/10)./sum(BSs.allowedRBs,2).*simParams.powerMultFactor;
    for b = 1:length(BSs.x)
        % Determine useable RBs at the BS
        allowedRBs{b} = find(BSs.allowedRBs(b,:)>0);
        % Set the maximum transmission power on each RB
        transmissionPower(b,allowedRBs{b}) = maxTransmitPower(b);
    end
elseif WAT == 1 % LiFi
    electricalPowerSubcarrier = (simParams.LAPTxOptPower^2)./((simParams.LAPopt2elec^2)*(simParams.LAPIDFTpoints-2));
    maxTransmitPower = electricalPowerSubcarrier.*ones(length(BSs.x),1);
    for b = 1:length(BSs.x)
        allowedRBs{b} = find(BSs.allowedRBs(b,:)>0);
        transmissionPower(b,allowedRBs{b}) = maxTransmitPower(b);
    end
end

%% Compute interference under the assumption of using full transmission power at all eNBs
[~,~,interference] = calculateSINR(allocation, transmissionPower, channelCoefficients, BSs, MSs, simParams, WAT);

%% Compute SINR
%% eNB
if WAT == 0
    for i = MSs.activeUsers_eNB,
        % Calculate SINR based on computed interference
        allRBsSINR(i,:) = abs(sqrt(maxTransmitPower(MSs.connectedBS(i)))...
            .*reshape(channelCoefficients(i,MSs.connectedBS(i),:),1,[])).^2 ./ interference(i,:);
        % Carry SINR of user i on the allowed RBs
        currentSINR(i,allowedRBs{MSs.connectedBS(i)}) = allRBsSINR(i,allowedRBs{MSs.connectedBS(i)});
    end
    %% LiFi AP
elseif WAT == 1
    for i = MSs.activeUsers_LAP,
        electricalPowerSubcarrier = (simParams.LAPTxOptPower^2)./((simParams.LAPopt2elec^2)*(simParams.LAPIDFTpoints-2));
        maxTransmitPower = electricalPowerSubcarrier.*ones(length(BSs.x),1);
        % Calculate SINR based on computed interference
        allRBsSINR(i,:) = maxTransmitPower(MSs.connectedAP(i))...
            .*(reshape(channelCoefficients(i,MSs.connectedAP(i),:),1,[]).*simParams.PD_resp).^2 ./ interference(i,:);
        % Carry SINR of user i on the allowed RBs
        currentSINR(i,allowedRBs{MSs.connectedAP(i)}) = allRBsSINR(i,allowedRBs{MSs.connectedAP(i)});
    end
end
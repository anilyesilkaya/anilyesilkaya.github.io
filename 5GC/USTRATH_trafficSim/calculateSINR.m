function [SINR, usefulPower, interference] = calculateSINR(assignedRBs, transmissionPower, channelCoefficients, BSs, UE, simParams, WAT)
%Calculates achieved SINR based on the allocated RBs and transmission power
%
% Created by: Stefan Videv, UoE, April 2010
%
% Update - 29/11/2019
% Parameter "WAT" is added to decide wireless access technology when UE
% related information is checked/updated - for example: connected BS or
% LiFi AP or WiFi AP
% WAT = 0 -> eNB
% WAT = 1 -> LiFi AP


usefulPower = zeros(length(UE.x),size(transmissionPower,2));
interference = zeros(length(UE.x),size(transmissionPower,2));

%% For eNB
if WAT == 0
    noiseFloor = 1.38*10^(-23)*5500*simParams.resourceBandwidth;
    for i = UE.activeUsers_eNB,
        for j = 1:length(BSs.x),
            if simParams.PCOn >= 0 % FM or User Group based PC
                if UE.connectedBS(i) == j,
                    usefulPower(i,:) = (assignedRBs(j,:) == i).*abs(sqrt(transmissionPower(j,:)).*reshape(channelCoefficients(i,j,:),1,[])).^2;
                else
                    if simParams.bitFill == 0
                        interference(i,:) = interference(i,:) + (assignedRBs(j,:) > 0).*abs(sqrt(transmissionPower(j,:)).*abs(reshape(channelCoefficients(i,j,:),1,[]))).^2;
                    else
                        interference(i,:) = interference(i,:) + (BSs.allowedRBs(j,:) > 0).*abs(sqrt(transmissionPower(j,:)).*abs(reshape(channelCoefficients(i,j,:),1,[]))).^2;
                    end
                end
            else % PCOff
                maxTransmitPower = 10^((simParams.BSPower-30)/10)./sum(BSs.allowedRBs,2).*simParams.powerMultFactor;
                if UE.connectedBS(i) == j,
                    usefulPower(i,:) = (assignedRBs(j,:) == i).*abs(sqrt(maxTransmitPower(j)).*reshape(channelCoefficients(i,j,:),1,[])).^2;
                else
                    if simParams.bitFill == 0
                        interference(i,:) = interference(i,:) + (assignedRBs(j,:) > 0).*abs(sqrt(maxTransmitPower(j)).*abs(reshape(channelCoefficients(i,j,:),1,[]))).^2;
                    else
                        interference(i,:) = interference(i,:) + (BSs.allowedRBs(j,:) > 0).*abs(sqrt(maxTransmitPower(j)).*abs(reshape(channelCoefficients(i,j,:),1,[]))).^2;
                    end
                end
            end
        end
    end
%% For LiFi AP
elseif WAT == 1
    noiseFloor = simParams.LiFinoisePSD*simParams.LAPresourceBandwidth; % per subcarrier (tone)
    for i = UE.activeUsers_LAP,
        for j = 1:length(BSs.x),
            if simParams.PCOn >= 0 % FM or User Group based PC
                if UE.connectedAP(i) == j,
                    usefulPower(i,:) = (assignedRBs(j,:) == i).*abs(transmissionPower(j,:)).*(reshape(channelCoefficients(i,j,:),1,[]).*simParams.PD_resp).^2;
                else
                    if simParams.bitFill == 0
                        interference(i,:) = interference(i,:) + (assignedRBs(j,:) > 0).*abs(transmissionPower(j,:))...
                            .*(reshape(channelCoefficients(i,j,:),1,[]).*simParams.PD_resp).^2;
                    else
                        interference(i,:) = interference(i,:) + (BSs.allowedRBs(j,:) > 0).*abs(transmissionPower(j,:))...
                            .*(reshape(channelCoefficients(i,j,:),1,[]).*simParams.PD_resp).^2;
                    end
                end
            else % PCOff
                electricalPowerSubcarrier = (simParams.LAPTxOptPower^2)./((simParams.LAPopt2elec^2)*(simParams.LAPIDFTpoints-2));
                maxTransmitPower = electricalPowerSubcarrier.*ones(length(BSs.x),1);
                if UE.connectedAP(i) == j,
                    usefulPower(i,:) = (assignedRBs(j,:) == i).*maxTransmitPower(j).*(reshape(channelCoefficients(i,j,:),1,[]).*simParams.PD_resp).^2;
                else
                    if simParams.bitFill == 0
                        interference(i,:) = interference(i,:) + (assignedRBs(j,:) > 0).*maxTransmitPower(j)...
                            .*(reshape(channelCoefficients(i,j,:),1,[]).*simParams.PD_resp).^2;
                    else
                        interference(i,:) = interference(i,:) + (BSs.allowedRBs(j,:) > 0).*maxTransmitPower(j)...
                            .*(reshape(channelCoefficients(i,j,:),1,[]).*simParams.PD_resp).^2;
                    end
                end
            end
        end
    end
end
%%
interference = interference + noiseFloor;

SINR = usefulPower./interference;
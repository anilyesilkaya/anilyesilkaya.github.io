function [SINR, usefulPower, interference] = calculateSINR_LiFi(assignedRBs, transmissionPower, channelCoefficients, noiseFloor, BSs, MSs, simParams)
%Calculates achieved SINR based on the allocated RBs and transmission power
%
% Created by: Stefan Videv, UoE, April 2010

usefulPower = zeros(length(MSs.x),size(transmissionPower,2));
interference = zeros(length(MSs.x),size(transmissionPower,2));


for i = MSs.activeUsers,
    for j = 1:length(BSs.x),
        if simParams.PCOn >= 0 % FM or User Group based PC
            if MSs.connectedBS(i) == j,
                usefulPower(i,:) = (assignedRBs(j,:) == i).*abs(sqrt(transmissionPower(j,:)).*reshape(channelCoefficients(i,j,:),1,[])).^2;
            else
                if simParams.bitFill == 0
                    interference(i,:) = interference(i,:) + (assignedRBs(j,:) > 0).*sqrt(transmissionPower(j,:)).*abs(reshape(channelCoefficients(i,j,:),1,[]));
                else
                    interference(i,:) = interference(i,:) + (BSs.allowedRBs(j,:) > 0).*sqrt(transmissionPower(j,:)).*abs(reshape(channelCoefficients(i,j,:),1,[]));
                end
            end
        else % PCOff
            maxTransmitPower = 10^((simParams.LAPPower-30)/10)./sum(BSs.allowedRBs,2).*simParams.powerMultFactor;
            if MSs.connectedAP(i) == j,
                usefulPower(i,:) = (assignedRBs(j,:) == i).*abs(sqrt(maxTransmitPower(j)).*reshape(channelCoefficients(i,j,:),1,[])).^2;
            else
                if simParams.bitFill == 0
                    interference(i,:) = interference(i,:) + (assignedRBs(j,:) > 0).*sqrt(maxTransmitPower(j)).*abs(reshape(channelCoefficients(i,j,:),1,[]));
                else
                    interference(i,:) = interference(i,:) + (BSs.allowedRBs(j,:) > 0).*sqrt(maxTransmitPower(j)).*abs(reshape(channelCoefficients(i,j,:),1,[]));
                end
            end
        end
    end
end

interference = interference + noiseFloor;

SINR = usefulPower./interference;
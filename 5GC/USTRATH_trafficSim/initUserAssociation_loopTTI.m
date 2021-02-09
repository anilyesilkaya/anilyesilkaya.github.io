function [UE, LED, eNB] = initUserAssociation_loopTTI(systemParameters,userLocations,UE,LED,eNB)

%%
% Free-space path loss at reference distance d0=1m for 1.8 GHz
FSPL = 37.5; % [dB]
stdFastFading = 10^(systemParameters.stdFastFading/10);
meanFastFading = 10^(systemParameters.meanFastFading/10);

totalUsers = size(userLocations,1);

UE.connectedBS  = zeros(1,totalUsers);

eNB.allowedRBs  = ones(systemParameters.numBS,systemParameters.eNBnumRBs);
LED.allowedRBs  = ones(systemParameters.Nt   ,systemParameters.LAPnumRBs);
%% Initialize connected UE in the eNB and LED structures
eNB.connectedUE = cell(1,systemParameters.numBS);
LED.connectedUE = cell(1,systemParameters.Nt);

for u=1:totalUsers
    UE.x(u) = userLocations(u,1);
    UE.y(u) = userLocations(u,2);
    UE.z(u) = userLocations(u,3);
    %% Assign UE to BS/femtocell
    for bs = 1:systemParameters.numBS
        eNBlocations(bs,:) = [eNB.x(bs), eNB.y(bs), eNB.z(bs)];
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
        APlocations(t,:) = [LED.x(t), LED.y(t), LED.z(t)];
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
    end
    %     % Plot line to clearly see the connected users
    %     hold on;
    %     plot([LED.x(selectedAP),UE.x(u)],[LED.y(selectedAP),UE.y(u)],'k-','HandleVisibility','off')
    %     drawnow
end






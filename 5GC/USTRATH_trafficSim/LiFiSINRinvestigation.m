% LiFi SINR investigation
clear all;clc
%% Initialize parameters
roomDimensions      = [4 4 3];  % [m] - should be a square room for now
UE.numUser          = 100;       % number of users
LED.numAPs          = 4;        % number of LiFi APs - sqrt(numAPs) should be an integer
LED.direction       = [0 0 -1]; % downwards
UE.direction        = [0 0 1];  % upwards

noisePSD            = 1e-21;    % Noise power spectral density [A^2/Hz]
IDFTpoints          = 256;      % number of IDFT points
deviceBW            = 20e6;     % Device communication bandwidth [Hz]
resourceBW          = deviceBW/IDFTpoints; % subcarrier bandwidth [Hz]

semiAngle           = 60;       % LED semi-angle [deg]
LambertianOrder     = -log(2)./log(cosd(semiAngle)); % Lambertian Order
RxFoV               = 45;       % PD field-of-view (FoV) [deg]
area_Eff            = 1e-4;     % Effective area of the receiver [m^2] -> given for 1 cm^2
optFilterGain       = 1;        % optical filter gain
concentratorGain    = 1;        % concentrator gain
PD_resp             = 0.6;     % [A/W] - based on Cheng's papers - can be 0.4 and 0.6 as well

TxOptPower_dBm      = [10,24,40]; % optical transmission power [dBm]
DCbiasFactor        = 3;      % DC bias factor - based on Cheng's papers

%% Room dimensions
x_dim = [-roomDimensions(1)/2:0.01:roomDimensions(1)/2]; % [m]
y_dim = [-roomDimensions(2)/2:0.01:roomDimensions(2)/2]; % [m]

%% AP location - works for a square room
APradius = roomDimensions(1)/(2*sqrt(LED.numAPs)); % [m] - equally distribute LiFi APs
APlocsx = -roomDimensions(1)/2+APradius:2*APradius:roomDimensions(1)/2-APradius;
APlocsy = -roomDimensions(2)/2+APradius:2*APradius:roomDimensions(2)/2-APradius;
LED.x = reshape(repmat(APlocsx,sqrt(LED.numAPs),1),[],1);
LED.y = repmat(APlocsy,1,sqrt(LED.numAPs))';
LED.z = roomDimensions(3).*ones(LED.numAPs,1);

%% Users and their location
UE.height = 0.85; % [m]
% Generate random user locations
UE.x = randsrc(UE.numUser,1,x_dim);
UE.y = randsrc(UE.numUser,1,y_dim);
UE.z = UE.height.*ones(1,UE.numUser);

%% Plot geometry
figure;
plot(LED.x,LED.y,'r^ ','LineWidth',1.5,'MarkerSize',8);hold on;
plot(UE.x,UE.y,'ko ','LineWidth',1.5,'MarkerSize',4);
xlim([-roomDimensions(1)/2 roomDimensions(1)/2]);
ylim([-roomDimensions(2)/2 roomDimensions(2)/2]);
xticks(-roomDimensions(1)/2:2*APradius:roomDimensions(1)/2);
yticks(-roomDimensions(2)/2:2*APradius:roomDimensions(2)/2);
grid on
xlabel('x-axis [m]');ylabel('y-axis [m]');
legend('AP','User');
set(findall(gcf,'-property','FontSize'),'FontSize',18)
set(findall(gcf,'-property','FontName'),'FontName','Arial')
set(findall(gcf,'-property','interpreter'),'interpreter','latex')
set(gca,'TickLabelInterpreter','latex')
hold on;

%% Initialize variables
UE.connectedAP = zeros(1,UE.numUser);
LED.connectedUE = cell(1,LED.numAPs);
power_Watt = 10.^((TxOptPower_dBm-30)./10);
rxPow = zeros(UE.numUser,length(TxOptPower_dBm)); % Received power level
SNRs_dB = zeros(size(rxPow)); % SNR in dB
SINRs_dB = zeros(size(rxPow)); % SINR in dB
intPow = zeros(size(rxPow)); % interference power
ints = cell(length(TxOptPower_dBm),1); % interference from each AP to each UE
% Noise Floor
nF = noisePSD*resourceBW;

%% Obtain channel gain and associate UEs to LiFi APs
for u = 1:UE.numUser
    for t = 1:LED.numAPs
        % Calculate distance, incidence and divergence angles based on
        % UE/LED direction and position
        [incidenceAngle(t,u),divergenceAngle(t,u),LED.distance(t,u)] = ...
            calculateAngle(LED.direction,UE.direction,...
            [LED.x(t),LED.y(t),LED.z(t)],...
            [UE.x(u), UE.y(u), UE.z(u)]);
        % Rect function gives 1 if incidence angle is in Rx FoV
        [LED.Rect(t,u), ~ ] = rect(incidenceAngle(t,u),RxFoV,1,[]);
        % Calculate channel gain
        if divergenceAngle(t,u) > 90
            LED.H(u,t) = 0;
        else
            LED.H(u,t) = optFilterGain*concentratorGain*...
                (LambertianOrder+1)*...
                cosd(divergenceAngle(t,u))^(LambertianOrder)...
                *cosd(incidenceAngle(t,u))*LED.Rect(t,u)*area_Eff/(2*pi*(LED.distance(t,u)^2));
        end
        H_NtLEDs(1,t) = LED.H(u,t);
    end
    UE.allChGain(u,:) = H_NtLEDs;
    % Associate UE u to the AP that has the highest channel gain
    [maxChGainValue(u),maxChGainAPindex] = max(UE.allChGain(u,:));
    % Check the gain is not 0, if it is, do not associate UE to any AP
    if maxChGainValue(u) == 0
        continue
    else
        % Check the gain is not same with any other AP, if it is, randomly
        % allocate
        maxValsIndex = find(UE.allChGain(u,:)==maxChGainValue(u));
        selectedAP = randsrc(1,1,maxValsIndex);
        clear maxValsIndex
        UE.connectedAP(u) = selectedAP;
        LED.connectedUE{selectedAP} = [LED.connectedUE{selectedAP}, u];
        % Plot line to clearly see the connected users
        plot([LED.x(selectedAP),UE.x(u)],[LED.y(selectedAP),UE.y(u)],'k-','HandleVisibility','off')
        %     drawnow
    end
end

%% Loop for different transmission power levels to obtain SNR and SINR
for pwLev = 1:length(power_Watt)
    ints{pwLev} = zeros(UE.numUser,LED.numAPs);
    % Calculate electrical transmission power for each subcarrier
    pTx = power_Watt(pwLev)^2./(((DCbiasFactor)^2)*(IDFTpoints-2));
    for tLED=1:LED.numAPs
        for ut = 1:UE.numUser
            if ismember(ut,LED.connectedUE{tLED})
                rxPow(ut,pwLev) = pTx*(LED.H(ut,tLED).*PD_resp).^2;
                SNRs_dB(ut,pwLev) = 10*log10(rxPow(ut,pwLev)./nF);
            else
                ints{pwLev}(ut,tLED) = pTx*(LED.H(ut,tLED,:).*PD_resp).^2;
                intPow(ut,pwLev) = intPow(ut,pwLev) + ints{pwLev}(ut,tLED);
            end
        end
        SINRs_dB(:,pwLev) = 10.*log10(rxPow(:,pwLev)./(intPow(:,pwLev)+nF));
        % Randomly choose one of the LiFi APs and consider it is active and
        % only AP that creates interference to the user
        random1APSINR_dB(:,pwLev) = 10.*log10(rxPow(:,pwLev)./(ints{pwLev}(:,randperm(LED.numAPs,1))+nF));
        random2APSINR_dB(:,pwLev) = 10.*log10(rxPow(:,pwLev)./(sum(ints{pwLev}(:,randperm(LED.numAPs,2)),2)+nF));
    end
end

%% Plot results
colorSet = [0,0,1; 1,0,0; 0, 0, 0; 0, 1, 0];
figure;hold on;
for v=1:length(power_Watt)
    h=cdfplot(SINRs_dB(:,v));
    h.LineStyle = '-';
    h.DisplayName = sprintf('P_t_x = %d dBm',TxOptPower_dBm(v));
    h.Color = colorSet(v,:);
    clear h
end
hold off;

figure;hold on;
for v=1:length(power_Watt)
    h=cdfplot(SNRs_dB(:,v));
    h.LineStyle = '-';
    h.DisplayName = sprintf('P_t_x = %d dBm',TxOptPower_dBm(v));
    h.Color = colorSet(v,:);
    clear h
    h=cdfplot(random1APSINR_dB(:,v));
    h.LineStyle = '--';
    h.DisplayName = sprintf('P_t_x = %d dBm, random 1 AP',TxOptPower_dBm(v));
    h.Color = colorSet(v,:);
    clear h
    h=cdfplot(random2APSINR_dB(:,v));
    h.LineStyle = '-.';
    h.DisplayName = sprintf('P_t_x = %d dBm, random 2 AP',TxOptPower_dBm(v));
    h.Color = colorSet(v,:);
    clear h
end
hold off
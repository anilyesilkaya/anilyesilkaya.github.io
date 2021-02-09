function [allocation, transmissionPower, SINRTargets, bitsSymbol, MSs, BSs, schedulingObjective] = proportionalFairScheduler...
    (simParams, MSs, BSs, channelCoefficients, currentAllocation, SINRTargets, bitsSymbol, ...
    currentSINR, TTIindex, currentSchedulingObjective, WAT)
%% Frequency-selective proportional fair scheduler
% Finds a user who maximizes the scheduling objective on a given RB and
% allocates the RB to this user. If the RB is used in another channel, then
% the scheduler finds the user who maximizes the scheduling objective on a
% given RB on the remaining channel and allocates the RB to the user on the
% remaining channel - this can be done based on given method woABS/ABS/RPABS
%
% 10/11/2016: Common MCS assignment is added for subband CQI reporting
%
% Update - 29/11/2019
% Parameter "WAT" is added to decide wireless access technology when UE
% related information is checked/updated - for example: connected BS or
% LiFi AP or WiFi AP
% WAT = 0 -> eNB
% WAT = 1 -> LiFi AP


%% Initialize Variables
allocation          = currentAllocation;
transmissionPower   = zeros(length(BSs.x),size(allocation,2));
% instantRate         = zeros(length(MSs.x),1);
schedulingObjective = currentSchedulingObjective;
% In case of ABS (or RPABS)
flaggedCHs          = zeros(length(BSs.x),1); % Indicates a cell-edge user is scheduled and interfering eNB should schedule center/middle users (RPABS) or be blanked (ABS)

%% Pre-compute achievable rate on each RB for each user, and scheduling objective
[schedulingObjective, SINRTargets, bitsSymbol] = calculateSchedulingObjective(simParams, BSs, MSs, currentSINR, [], 0,...
    schedulingObjective, SINRTargets, bitsSymbol, flaggedCHs, WAT);

%% Arrange RBs based on allocation type
% if simParams.RAtype == -1 % theoretical, each RB can be assigned
%     RBlist = 1:simParams.numberRBs - 24;
% elseif simParams.RAtype == 0 % RBs are assigned as groups
%     RBlist = [1:4:273, 276:4:376]; % due to 15 MHz channel (75 RBs in total), one of the RBG has 3 RBs
% end
%% eNB
if WAT == 0
    RBlist = 1:4:101;
    %% LiFi AP
elseif WAT == 1
    %     RBlist = 1:simParams.LAPsubcarriersPerResource:simParams.LAPnumSubcarriers+1; % +1 is used to calculate RBsInRBG in a systematic way
    RBlist = 1:simParams.LAPnumRBs+1;
end
% RBlist = [RBlist, 100];
%% Allocate
[allocation, SINRTargets, bitsSymbol, BSs, MSs, schedulingObjective] = PFS(simParams, BSs, MSs, currentSINR, ...
    schedulingObjective, RBlist, allocation, SINRTargets, bitsSymbol, TTIindex, flaggedCHs, WAT);

%% IF Practical Case is considered, Assign Common MCS
if simParams.simulationCase == 2
    failedRBs{1} = 1;
    counter = 0;
    while sum(logical([failedRBs{:}])) ~= 0
        % Assign Common MCS index and check is there any released RBs after
        % common MCS assignment
        [bitsSymbol, SINRTargets, MSs, BSs, failedRBs, allocation, currentSINR] = commonMCSassignment(simParams, MSs, BSs, TTIindex, ...
            bitsSymbol, SINRTargets, allocation, currentSINR, WAT);
        % Leave the failed RBs unallocated, leave while loop
        if counter > 20
            break
        end
        % Try to allocate released RBs
        if sum(logical([failedRBs{:}])) > 0
            counter = counter + 1;
            [allocation, SINRTargets, bitsSymbol, BSs, MSs, schedulingObjective] = PFS(simParams, BSs, MSs, currentSINR, ...
                schedulingObjective, RBlist, allocation, SINRTargets, bitsSymbol, TTIindex, flaggedCHs, WAT);
        else
            break % all RBs are allocated, leave while loop
        end
    end
end

%% Assign Transmission Power
if simParams.ABS == 0
    if WAT == 0
        maxTransmitPower = 10^((simParams.BSPower-30)/10)./sum(BSs.allowedRBs,2).*simParams.powerMultFactor;
    elseif WAT == 1
        electricalPowerSubcarrier = (simParams.LAPTxOptPower^2)./((simParams.LAPopt2elec^2)*(simParams.LAPIDFTpoints-2));
        maxTransmitPower = electricalPowerSubcarrier.*ones(length(BSs.x),1);
    end
else
    for b=1:length(BSs.x)
        maxTransmitPower(b) = max(unique(transmissionPower(b,:)));
    end
end

if simParams.PCOn == 0 % Equally distribute total transmission power to RBs
    %     transmissionPower   = repmat(maxTransmitPower,1,simParams.numberRBs).*BSs.allowedRBs;
    if WAT == 0
        transmissionPower   = repmat(maxTransmitPower,1,simParams.eNBnumRBs).*logical(allocation);
    elseif WAT == 1
        transmissionPower   = repmat(maxTransmitPower,1,simParams.LAPnumRBs).*logical(allocation);
    end
elseif simParams.PCOn == 1 % Foschini-Miljanic Power Control Algorithm /% can only be used with ideal case
    if WAT == 0
        transmissionPower   = repmat(maxTransmitPower,1,simParams.eNBnumRBs).*BSs.allowedRBs;
        [allocation, transmissionPower, SINRTargets, bitsSymbol] = powerControlFoschiniMiljanic(allocation, transmissionPower, channelCoefficients, ...
            BSs, MSs, SINRTargets, bitsSymbol, simParams, maxTransmitPower);
    elseif WAT == 1
        error('No FM power control for LiFi')
    end
elseif simParams.PCOn == 2 % User Grouping Based Power Control Algorithm
    if WAT == 0
        transmissionPower = powerControlUserGroup(allocation, MSs, BSs, simParams, maxTransmitPower);
    elseif WAT == 1
        error('No user grouping based power control for LiFi')
    end
end
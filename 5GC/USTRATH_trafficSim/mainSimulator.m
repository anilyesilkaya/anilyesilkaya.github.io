% Li-Drive main code
% LiFi AP has a storage capacity.
% UE uploads the requested content to the LiFi AP.
% If an UE requests the content that is already available in the LiFi AP,
% it downloads it from the LiFi AP.
% Thus, (i) burden on the macrocellular network will be reduced;
% (ii) the latency will be reduced;
% (iii) UE does not need to have a huge storage capability.
%
%
%
% Created by Tezcan Cogalan, UoE, October 2019
%
clear all;clc
%% Describe system parameters
% Room dimensions at x,y,z plane in [m] -> [x,y,z].
systemParameters.roomDim   = [20 20 3];
% Number of access points in the system
systemParameters.Nt  = 25; % 5-by-5
% Number of users in the system
systemParameters.numUserPerAP = 5;
% # of PDs at the receiver
systemParameters.Nr        = 1;
% LED DC bias - based on Lampe's paper [is it dB?]
systemParameters.P_dc       = 20e-3;
% LED linearity constant - based on Lampe's paper alpha \in [0,1]
systemParameters.alpha     = 0.2;
% Perturbing noise (epsulon) std. variation
systemParameters.pertSigma = 1e-20;
% Monte-carlo simulation length
systemParameters.monte     = 1e3;

%%% LED and PD parameters %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% LED semi-angle [deg]
systemParameters.LEDsemiAngle      = 60;
% LED Lambertian order
systemParameters.LambOrder         = -log(2)./log(cosd(systemParameters.LEDsemiAngle));
% LED direction - downwards
systemParameters.LEDdirection      = [0 0 -1];
% PD direction - upwards
systemParameters.PDdirection       = [0 0 1];
% PD field-of-view (FoV) [deg]
systemParameters.RxFOV             = 70;
% Height of the receive plane [m]
systemParameters.RxHeight          = 0.85;
% Optical filter gain
systemParameters.optFilterGain     = 1;
% Contentrator gain
systemParameters.ConcentratorGain  = 1;
% Effective area of the receiver [m^2] -> given for (1cm^2)
systemParameters.Area_eff          = 1.0000e-04;
% Grid length - Receive plane is divided into square grids [m]
systemParameters.gridSize  = 0.01; % 1cm
% Number of considered random locations in the performance evaluation
systemParameters.numRanLoc = 1;

%%% Caching parameters %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
systemParameters.numFiles = 2e1;
systemParameters.randomFileSize = 1;
if systemParameters.randomFileSize == 0
    % 1 byte = 8 bits => 10 megabyte file size
    systemParameters.bitsPerFile = 8*10e6;
    systemParameters.libraryBitSize = systemParameters.numFiles*systemParameters.bitsPerFile;
else
    % 1 byte = 8 bits => randomly chosen 1 kilobyte to 1 gigabyte file size
    systemParameters.bitsPerFile = randsrc(1,systemParameters.numFiles,8.*[1e3:1e3:1e9]);
    systemParameters.libraryBitSize = sum(systemParameters.bitsPerFile);
end
systemParameters.cacheSizeFraction = 0.5; % \in {0,1}
systemParameters.cacheSizeBits = systemParameters.libraryBitSize*systemParameters.cacheSizeFraction;
systemParameters.ZipfParameter = 0.9; % 0.8 <= ZipfParameter <= 1.2

% Poisson parameters
systemParameters.poissonLambda = 4/(60*1e3); % Poisson rate per millisecond; 4 requests per 1 minute

systemParameters.simulationDuration = 1e3*60*1; % Simulation time in milliseconds; 60 minutes


%% Initialize geometry
[userLocations, APlocations] = initGeometry(systemParameters);

%% Generate channel and associate users to the AP that has the highest gain
[UE, LED] = initUserAssociation(systemParameters,userLocations,APlocations);

%% Generate content's size, popularity
[file] = ZipfContentPopularity(systemParameters.numFiles,systemParameters.ZipfParameter,systemParameters.bitsPerFile);

%% Determine UE request arrivals and requested content
% Initialize file set
fileSet = 1:systemParameters.numFiles;
% Obtain cumulative summation of the file popularity
C = cumsum(file.popularity);
% Consider each cell individually
for i=1:systemParameters.Nt
    % Generate user requests for each cell
    [LED(i).eventTime,LED(i).occurance] = poissonArrivals(systemParameters.poissonLambda,systemParameters.simulationDuration);
    % Obtain number of generated events
    LED(i).numEvent = length(LED(i).eventTime);
    % Initialize remaining event list
    LED(i).remainingEvents = 1:LED(i).numEvent;
end

%% Compute performance
% Initialize simulation timer (ms resolution)
sTime = 0;
simulationFlag = zeros(systemParameters.Nt,1);
activeLEDs = 1:systemParameters.Nt;
activeTimeLEDs = zeros(systemParameters.Nt,1);
eNBqueue = [];
while sum(simulationFlag) < systemParameters.Nt
    sTime = sTime + 1;
    activeTimeLEDs(:,sTime) = zeros(systemParameters.Nt,1);
    % Check is there any active LED at the given sTime
    for i = activeLEDs
        eventIndex = LED(i).remainingEvents(1);
        if LED(i).eventTime(eventIndex) == sTime
            % Pick a user that is connected to the cell i
            userIndex = randsrc(1,1,[LED(i).connectedUE]);
            LED(i).UEarrivalOrder(eventIndex) = userIndex;
            % Choose file based on the given Zipf distribution for each event/user
            requestedFile = fileSet(1+sum(rand>C));
            % Update UE structure details for requested file and request time
            UE(userIndex).requestedFile = [UE(userIndex).requestedFile, requestedFile];
            UE(userIndex).requestTime = [UE(userIndex).requestTime, LED(i).eventTime(eventIndex)];
            % Check the file is cached or not
            if ismember(LED(i).cachedFile,requestedFile) % LED serves the UE
                LED(i).activeTime(sTime) = 1;
                activeTimeLEDs(i,sTime) = 1;
            else % UE needs to be served by the macro/femto cell and upload the file to the LED
                eNBqueue = [eNBqueue,userIndex];
                downloadContent
                uploadContent
                LED(i).cachedFile = [LED(i).cachedFile,requestedFile];
            end
        end
    end

            
        
    % If there is
    for i = activeLEDs
        eventIndex = LED(i).remainingEvents(1);
        if sTime ~= LED(i).eventTime(eventIndex)
            continue
        else
            
            
            
            
            if isempty(LED(i).remainingEvents)
                activeLEDs(activeLEDs==i) = [];
                simulationFlag(i) = 1;
            end
        end
        clear eventIndex
    end
end











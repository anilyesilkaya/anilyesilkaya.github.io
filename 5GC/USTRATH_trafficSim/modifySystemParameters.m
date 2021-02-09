function systemParameters = modifySystemParameters


%% Main system parameters
% Simulation time in milliseconds; 30 minutes
systemParameters.simulationDuration         = 1e3*60*3; 
% Monte-carlo simulation length
systemParameters.monte                      = 1e3;
% Room dimensions at x,y,z plane in [m] -> [x,y,z].
systemParameters.roomDim                    = [4 4 3];
% Number of access points in the system
systemParameters.Nt                         = 1; % 5-by-5
% Number of users in the system
systemParameters.numUserPerAP               = 5;
% # of PDs at the receiver
systemParameters.Nr                         = 1;
% Range for eNB random location
systemParameters.eNBrange                   = 50; % 100-by-100 square [m]
% Base station height range
systemParameters.BSheight                   = [systemParameters.roomDim(3):1:25];

systemParameters.PCOn                   = 0;        % (=0) Equally distributed; (=1) Foschini-Miljanic; (=2) User Group Based
systemParameters.BSPower                = 30;
systemParameters.powerMultFactor        = 1;
systemParameters.RAtype                 = 0;       % Bitmap based resource allocation (LTE RA type 0)
systemParameters.CQIreportType          = 110;   % Wideband CQI Reporting
systemParameters.bitFill                = 0;

%% eNB/femtocell channel parameters
systemParameters.alpha_n                = 1.5;  % path-loss exponent
systemParameters.sigma_L                = 7; % deviation in [dB]
systemParameters.stdFastFading          = 2.5;
systemParameters.meanFastFading         = 0;

%% eNB parameters
% 20 MHz channel can achieve roughly 100 Mbps when SINR > 20; 
% rate*12*7*5e-4*numRBs
systemParameters.numBS                      = 1;
systemParameters.eNBnumRBs                  = 100;   % 20 MHz channel
systemParameters.LAPnumRBs                  = 20;    % 20 MHz channel
systemParameters.subcarriersPerResource     = 12;    % 12 subcarriers per RB
systemParameters.symbolsTS                  = 7;     % 7 OFDM symbols per TS
systemParameters.TSduration                 = 5e-4;  % 0.5 ms
systemParameters.resourceBandwidth          = 180e3; % 180 kHz
systemParameters.dataRateFairnessThreshold  = Inf;   % no data rate threshold
systemParameters.averagingPeriod            = 10;    % averaging windows size of TTIs
systemParameters.simulationCase             = 2;        % (=1) Ideal Case; (=2) Practical Case
systemParameters.ABS                        = 0;        % (=0) without CoMP; (=1) ABS; (=2) RPABS


%% LiFi AP parameters - 802.11ax based parameters
% IDFT points - K - (2^x) => 128, 256, 512, 1024..
% In 802.11ax, 20 MHz channel has 256 subcarriers and different
% number of resource units (RUs)
% 9 x 26-tone (subcarrier)
% 4 x 52-tone + 1 x 26-tone
% 2 x 106-tone + 1 x 26-tone
% 1 x 242-tone
% However, the number of subcarriers is considered as 512 (for 20 MHz) as
% in LiFi systems half of the subcarriers are wasted due to Hermitian symmetry
systemParameters.LAPIDFTpoints              = 256;      % number of IDFT points
systemParameters.LAPnumRBs                  = 1;        % 1 x 242-tone - 20 MHz channel
systemParameters.LAPsubcarriersPerResource  = 242;      % 242 subcarriers per RB (RU - resource unit in WiFi jargon)
systemParameters.LAPnumSubcarriers          = systemParameters.LAPnumRBs*systemParameters.LAPsubcarriersPerResource; % # of data subcarriers
systemParameters.LAPsymbolsTS               = 1;        % 1 OFDM symbols per TS
systemParameters.LAPTSduration              = 12.8e-6;  % 12.8 us
systemParameters.LAPresourceBandwidth       = 78.125e3; % 78.125 kHz
systemParameters.modulationBandwidth        = systemParameters.LAPnumRBs*systemParameters.LAPsubcarriersPerResource*systemParameters.LAPresourceBandwidth; % Actual data carrying bandwidth

%% LED and PD parameters
% LED semi-angle [deg]
systemParameters.LEDsemiAngle      = 60;
% LED Lambertian order
systemParameters.LambOrder         = -log(2)./log(cosd(systemParameters.LEDsemiAngle));
% LED direction - downwards
systemParameters.LEDdirection      = [0 0 -1];
% PD direction - upwards
systemParameters.PDdirection       = [0 0 1];
% PD field-of-view (FoV) [deg]
systemParameters.RxFOV             = 45;
% Height of the receive plane [m]
systemParameters.RxHeight          = 0.85;
% Optical filter gain
systemParameters.optFilterGain     = 1;
% Contentrator gain
systemParameters.ConcentratorGain  = 1;
% Effective area of the receiver [m^2] -> given for (1cm^2)
systemParameters.Area_eff          = 1.0000e-04;
% Grid length - Receive plane is divided into square grids [m]
systemParameters.gridSize          = 0.01; % 1cm
% Number of considered random locations in the performance evaluation
systemParameters.numRanLoc         = 1;

% Responsitivity of the PD [A/W]
systemParameters.PD_resp           = 0.6;
% Optical transmission power of LED [W]
systemParameters.LAPTxOptPower     = 10^((40-30)/10); % 40 dBm - 10 Watt is considered based on Cheng's paper.
% Optical-to-Electrical (O/E) conversion - DC bias factor!!
systemParameters.LAPopt2elec       = 3;
% Noise power spectral density [A^2/Hz]
systemParameters.LiFinoisePSD      = 1.0000e-21;   

%% Caching parameters
systemParameters.numFiles = 2e1;
systemParameters.randomFileSize = 0;
if systemParameters.randomFileSize == 0
    % 1 byte = 8 bits => 10 megabyte file size = 80 megabits
    systemParameters.bitsPerFile = 80*1e6.*ones(1,systemParameters.numFiles);
    systemParameters.libraryBitSize = sum(systemParameters.bitsPerFile);
else
    % 1 byte = 8 bits => randomly chosen 1 kilobyte to 1 gigabyte file size
    systemParameters.bitsPerFile = randsrc(1,systemParameters.numFiles,8.*[1e3:1e3:1e9]);
    systemParameters.libraryBitSize = sum(systemParameters.bitsPerFile);
end
systemParameters.cacheSizeFraction = 0.2; % \in {0,1}
systemParameters.cacheSizeBits = systemParameters.libraryBitSize*systemParameters.cacheSizeFraction;
systemParameters.ZipfParameter = 0.9; % 0.8 <= ZipfParameter <= 1.2

%% Poisson parameters
systemParameters.poissonLambda = 4/(60*1e3); % Poisson rate per millisecond; 4 requests per 1 minute
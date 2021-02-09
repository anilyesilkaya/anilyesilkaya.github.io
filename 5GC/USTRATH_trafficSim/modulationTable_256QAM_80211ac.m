function [SINRTarget, bitsSymbol] = modulationTable_256QAM_80211ac(maxSINR,modulationBandwidth)
% matches max SINR to best fit in modulation table
% Based on EVM measurements at slide 30 in Agilent Presentation titled as
% Introduction to 802.11ac WLAN Technology and Testing - by Mirin Lew 2012
% The same EVM measurements are also available at "Introduction to Wireless
% LAN Measurements From 802.11a to 802.11ac" by National Instruments document.
% These measurements are probably taken from the table at:
% IEEE P802.11 Wireless LANs - CRs on 28.3.18 Transmit specification -
% doc.: IEEE 802.11-17/0290r5 - May 2017


% For EVM to SNR conversion, the following approximation is considered:
% SNR = 1/(EVM^2)
% For achievable rates, 802.11ax (short GI), instead of 802.11ac, rates
% for 20 MHz channel are considered.
% For spectral efficieny, modulation bandwidth is calculated as follows:
% #subcarriersPerResource x #RBs x subcarrierBandwidth
% For example, in 802.11ax, there are 9 RBs (RUs) x 26 subcarriers per RB
% or 1 RB x 242 subcarrier. Therefore, 802.11ax rates are obtained by:
% Rate (Mbps) / modulationBandwidth (MHz)
% 9 RB x 26 subcarrier  x 78.125 kHz per subcarrier = 18.3 MHz
% 1 RB x 242 subcarrier x 78.125 kHz per subcarrier = 18.9 MHz
%
% | Modulation | Coding Rate | 802.11ac | SNR     | Rate  | Spec   |
% |            |             | EVM      | 1/EVM^2 | Mbps  | b/s/Hz |
% |            |             |          |         |       |  1 RB  |
%-------------------------------------------------------------------
% | BPSK       | 1/2         | -5  dB   | 5 dB    | 8.6   | 0.4550 |
% | QPSK       | 1/2         | -10 dB   | 10 dB   | 17.2  | 0.9101 |
% | QPSK       | 3/4         | -13 dB   | 13 dB   | 25.8  | 1.3651 |
% | 16QAM      | 1/2         | -16 dB   | 16 dB   | 34.4  | 1.8201 |
% | 16QAM      | 3/4         | -19 dB   | 19 dB   | 51.6  | 2.7302 |
% | 64QAM      | 2/3         | -22 dB   | 22 dB   | 68.8  | 3.6402 |
% | 64QAM      | 3/4         | -25 dB   | 25 dB   | 77.4  | 4.0952 |
% | 64QAM      | 5/6         | -27 dB   | 27 dB   | 86.0  | 4.5503 |
% | 256QAM     | 3/4         | -30 dB   | 30 dB   | 103.2 | 5.4603 |
% | 256QAM     | 5/6         | -32 dB   | 32 dB   | 114.7 | 6.0688 |
%-------------------------------------------------------------------
%
if maxSINR >= 10^(5/10) && maxSINR < 10^(10/10)
    SINRTarget = 5;
    bitsSymbol = 8.6e6/modulationBandwidth;
elseif maxSINR >= 10^(10/10) && maxSINR < 10^(13/10)
    SINRTarget = 10;
    bitsSymbol = 17.2e6/modulationBandwidth;
elseif maxSINR >= 10^(13/10) && maxSINR < 10^(16/10)
    SINRTarget = 13;
    bitsSymbol = 25.8e6/modulationBandwidth;
elseif maxSINR >= 10^(16/10) && maxSINR < 10^(19/10)
    SINRTarget = 16;
    bitsSymbol = 34.4e6/modulationBandwidth;
elseif maxSINR >= 10^(19/10) && maxSINR < 10^(22/10)
    SINRTarget = 19;
    bitsSymbol = 51.6e6/modulationBandwidth;
elseif maxSINR >= 10^(22/10) && maxSINR < 10^(25/10)
    SINRTarget = 22;
    bitsSymbol = 68.8e6/modulationBandwidth;
elseif maxSINR >= 10^(25/10) && maxSINR < 10^(27/10)
    SINRTarget = 25;
    bitsSymbol = 77.4e6/modulationBandwidth;
elseif maxSINR >= 10^(27/10) && maxSINR < 10^(30/10)
    SINRTarget = 27;
    bitsSymbol = 86e6/modulationBandwidth;
elseif maxSINR >= 10^(30/10) && maxSINR < 10^(32/10)
    SINRTarget = 30;
    bitsSymbol = 103.2e6/modulationBandwidth;
elseif maxSINR >= 10^(32/10)
    SINRTarget = 32;
    bitsSymbol = 114.7e6/modulationBandwidth;
else
    SINRTarget = -Inf;
    bitsSymbol = 0;
end
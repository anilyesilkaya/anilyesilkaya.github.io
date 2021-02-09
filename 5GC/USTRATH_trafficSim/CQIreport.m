function [SINRtargetsCQI, bitsSymbolsCQI] = CQIreport(systemParameters,RBs,currentSINR,flaggedCH,WAT)
% CQI reporting scheme based on LTE specifications are applied [TS 36.213]
% Accordingly, mode for different periodic and aperiodic CQI reporting
% schemes are listed below.
%
% Periodic CQI Reporting using PUCCH:
% Wideband CQI              -> Mode 1-0 (no PMI); Mode 1-1 (single PMI)
% UE selected Subband CQI   -> Mode 2-0 (no PMI); Mode 2-1 (single PMI)
%
% Aperiodic CQI Reporting using PUSCH:
% Wideband CQI              -> Mode 1-0 (no PMI); Mode 1-1 (single PMI); Mode 1-2 (multiple PMI)
% UE selected Subband CQI   -> Mode 2-0 (no PMI); -------------------- ; Mode 2-2 (multiple PMI)
% eNB selected Subband CQI  -> Mode 3-0 (no PMI); Mode 3-1 (single PMI); Mode 3-2 (multiple PMI)
%
% Function description:
% Inputs:
%   systemParameters.CQIreportType = XYZ
%      X: Reporting type: 1-Periodic; 2-Aperiodic
%      Y: Mode          : 1-Wideband; 2-Subband (UE); 3-Subband(BS)
%      Z: PMI           : 0-No PMI;   1-Single PMI;   2-Multiple PMI
%   [Special case - Theoretical case: XYZ = 000]
%   RBs : 1-by-N_SystemRBs vector consisting with 0s and 1s to represent
%      allowed RBs at the BS which the user is connected.
%   currentSINR : 1-by-N_SystemRBs vector for a user
% Outputs:
%   SINRtargets : SINR target for RBs based on CQI reporting
%   bitsSymbols : Rate for RBs based on CQI reporting
%
% Written by Tezcan Cogalan, UoE, 12/04/2016.
% Version 1 (12/04/2016): Only wideband CQI reporting is considered.
% Version 2 (14/04/2016): Periodic Mode 2-0 and Aperiodic Mode 2-0 are added.
% Version 3 (20/09/2016): Theoretical case which is CQI with RB granularity
%                         is added (systemParameters.CQIreportType==000).
% Version 4 (10/11/2016): RP-ABS power reduction level based AMC is added
% Version 5 (09/12/2016): 256QAM option in the modulation table is added
% Version 6 (24/12/2019): 802.11ax 256QAM modulation table is added along
%                         with WAT option for LiFi AP (WAT==1).
%
if systemParameters.CQIreportType == 000 % Theoretical case, CQI of each RB
    SINRtargetsCQI = -Inf(1,length(RBs));
    bitsSymbolsCQI = zeros(1,length(RBs));
    totalRBs = find(RBs==1);
    for rb=totalRBs
        if WAT == 0 % eNB
            if isfield(systemParameters,'QAM256')
                [SINRtargetsCQI(rb),bitsSymbolsCQI(rb)] = modulationTable_256QAM((currentSINR(rb)));
            else
                [SINRtargetsCQI(rb),bitsSymbolsCQI(rb)] = modulationTable((currentSINR(rb)));
            end
        elseif WAT == 1 % LiFi AP - 802.11ax rates
            [SINRtargetsCQI(rb),bitsSymbolsCQI(rb)] = modulationTable_256QAM_80211ac((currentSINR(rb)),systemParameters.modulationBandwidth);
        end
    end
elseif systemParameters.CQIreportType == 110 || systemParameters.CQIreportType == 210 % Periodic Mode 1-0 or Aperiodic Mode 1-0, respectively
    SINRtargetsCQI = -Inf(1,length(RBs));
    bitsSymbolsCQI = zeros(1,length(RBs));
    %% Wideband CQI report - considers whole channel and reports only one
    % value for whole channel bandwidth.
    % Calculate average SINR on whole channel bandwidth for the user
    avgSINR = currentSINR*RBs'./sum(RBs);
    % Convert the average value to dB
    avgSINR_dB = 10.*log10(avgSINR);
    % Assign same SINR targets and bps to whole channel bandwidth
    if systemParameters.ABS == 2 && systemParameters.RPABSoffset == 6 && flaggedCH == 1
        [wideBandSINRtargets,wideBandBitsSymbols] = modulationTable_QPSK(avgSINR);
    elseif systemParameters.ABS == 2 && systemParameters.RPABSoffset == 3 && flaggedCH == 1
        [wideBandSINRtargets,wideBandBitsSymbols] = modulationTable_16QAM(avgSINR);
    else
        if WAT == 0 % eNB
            if isfield(systemParameters,'QAM256')
                [wideBandSINRtargets,wideBandBitsSymbols] = modulationTable_256QAM(avgSINR);
            else
                [wideBandSINRtargets,wideBandBitsSymbols] = modulationTable(avgSINR);
            end
        elseif WAT == 1% LiFi AP - 802.11ax rates
            [wideBandSINRtargets,wideBandBitsSymbols] = modulationTable_256QAM_80211ac(avgSINR,systemParameters.modulationBandwidth);
        end
    end
    SINRtargetsCQI(RBs>0) = wideBandSINRtargets;
    bitsSymbolsCQI(RBs>0) = wideBandBitsSymbols;
elseif systemParameters.CQIreportType == 120 % Periodic Mode 2-0 [TS 36213]
    if WAT == 0 % eNB
        %% UE selected subband CQI reporting
        % For 15 MHz and 20 MHz channels (#RBs 75 and 100, respectively):
        %   o Number of Subbands (SB)   = 9 for 15MHz and 12 for 20 MHz
        %   o Number of RBs per Subband = 8
        %   o Number of Bandwidth Parts = 4
        % UE reports one CQI of a subband in each bandwidth part
        % For 20 MHz
        % | SB1 | SB2 | SB3 | SB4 | SB5 | SB6 | SB7 | SB8 | SB9 | SB10 | SB11 | SB 12 |
        % |<-----BP1------->|<------BP2------>|<------BP3------>|<--------BP4-------->|
        % For 15 MHz
        % | SB1 | SB2 | SB3 | SB4 | SB5 | SB6 | SB7 | SB8 | SB9 |
        % |<---BP1--->|<---BP2--->|<---BP3--->|<------BP4------>|
        % Initialize function outputs: SINR targets and bit/symbol
        SINRtargetsCQI = -Inf(1,length(RBs));
        bitsSymbolsCQI = zeros(1,length(RBs));
        % Find allowed RB index
        allowedRBsIndex = find(RBs==1);
        % Find total number of allowed RBs
        totalRBs = length(allowedRBsIndex);
        % Calculate average CQI for subband
        for SBs = 1:floor(totalRBs/8) % #subbands = floor(total#RBs / #RBsPerSubband)
            if SBs ~= floor(totalRBs/8)
                subbandRBsIndex{SBs} = allowedRBsIndex(((SBs-1)*8+1):1:(SBs*8));
                avgSINR(SBs) = currentSINR(subbandRBsIndex{SBs})*ones(8,1)./8;
            else % 12th(9th) subband will have +4(+3) missing RBs from 100(75)/8 -- 20MHz(15MHz)
                subbandRBsIndex{SBs} = allowedRBsIndex(((SBs-1)*8+1):1:totalRBs);
                avgSINR(SBs) = currentSINR(subbandRBsIndex{SBs})*ones(8+(totalRBs-SBs*8),1)./(8+(totalRBs-SBs*8));
            end
            if systemParameters.ABS == 2 && systemParameters.RPABSoffset == 6 && flaggedCH == 1
                [subbandSINRTargets(SBs),subbandBitsSymbol(SBs)] = modulationTable_QPSK((avgSINR(SBs)));
            elseif systemParameters.ABS == 2 && systemParameters.RPABSoffset == 3 && flaggedCH == 1
                [subbandSINRTargets(SBs),subbandBitsSymbol(SBs)] = modulationTable_16QAM((avgSINR(SBs)));
            else
                if isfield(systemParameters,'QAM256')
                    [subbandSINRTargets(SBs),subbandBitsSymbol(SBs)] = modulationTable_256QAM((avgSINR(SBs)));
                else
                    [subbandSINRTargets(SBs),subbandBitsSymbol(SBs)] = modulationTable((avgSINR(SBs)));
                end
            end
            SINRtargetsCQI(subbandRBsIndex{SBs}) = subbandSINRTargets(SBs).*ones(1,length(subbandRBsIndex{SBs}));
            bitsSymbolsCQI(subbandRBsIndex{SBs}) = subbandBitsSymbol(SBs).*ones(1,length(subbandRBsIndex{SBs}));
        end
    elseif WAT == 1 % LiFi AP
        err('There is no support for UE selected subband CQI reporting at 802.11ax')
    end
elseif systemParameters.CQIreportType == 220 % Aperiodic Mode 2-0
    if WAT == 0 % eNB
        %% UE selected subband CQI reporting
        % For 15 MHz and 20 MHz channels (#RBs 75 and 100, respectively):
        %   o Number of Total Subbands      = 19 for 15MHz and 25 for 20 MHz
        %   o Number of RBs per Subband     = 4
        %   o Number of Selected Subbands(M)= 6
        % UE reports one CQI which is averaged over M selected subbands
        % Initialize function outputs: SINR targets and bit/symbol
        SINRtargetsCQI = -Inf(1,length(RBs));
        bitsSymbolsCQI = zeros(1,length(RBs));
        % Find allowed RB index
        allowedRBsIndex = find(RBs==1);
        % Find total number of allowed RBs
        totalRBs = length(allowedRBsIndex);
        % Calculate average SINR for subband
        for SBs = 1:ceil(totalRBs/4) % #subbands = ceil(total#RBs / #RBsPerSubband)
            if SBs ~= ceil(totalRBs/4)
                subbandRBsIndex{SBs} = allowedRBsIndex(((SBs-1)*4+1):1:(SBs*4));
                avgSINR(SBs) = currentSINR(subbandRBsIndex{SBs})*ones(4,1)./4;
            else % 12th(9th) subband will have +4(+3) missing RBs from 100(75)/8 -- 20MHz(15MHz)
                subbandRBsIndex{SBs} = allowedRBsIndex(((SBs-1)*4+1):1:totalRBs);
                avgSINR(SBs) = currentSINR(subbandRBsIndex{SBs})*ones(4+(totalRBs-SBs*4),1)./(4+(totalRBs-SBs*4));
            end
        end
        % Find 6 best subbands
        tempAvgSINR = avgSINR;
        for m=1:6
            [~,subbandIndex(m)] = max(tempAvgSINR);
            tempAvgSINR(subbandIndex(m)) = -Inf;
        end
        % Average 6 best subbands
        avgBestSubbandsSINR = avgSINR(subbandIndex)*ones(6,1)./6;
        % Calculate wideband SINR
        widebandSINR = avgSINR*ones(length(avgSINR),1)./length(avgSINR);
        % Determine SINR targets and bits/symbol
        for SBs = 1:ceil(totalRBs/4)
            if ismember(SBs,subbandIndex) % assign averaged best 6 subbands SINR
                if systemParameters.ABS == 2 && systemParameters.RPABSoffset == 6 && flaggedCH == 1
                    [subbandSINRTargets(SBs),subbandBitsSymbol(SBs)] = modulationTable_QPSK((avgBestSubbandsSINR));
                elseif systemParameters.ABS == 2 && systemParameters.RPABSoffset == 3 && flaggedCH == 1
                    [subbandSINRTargets(SBs),subbandBitsSymbol(SBs)] = modulationTable_16QAM((avgBestSubbandsSINR));
                else
                    if isfield(systemParameters,'QAM256')
                        [subbandSINRTargets(SBs),subbandBitsSymbol(SBs)] = modulationTable_256QAM((avgBestSubbandsSINR));
                    else
                        [subbandSINRTargets(SBs),subbandBitsSymbol(SBs)] = modulationTable((avgBestSubbandsSINR));
                    end
                end
            else % assign wideband SINR
                if systemParameters.ABS == 2 && systemParameters.RPABSoffset == 6 && flaggedCH == 1
                    [subbandSINRTargets(SBs),subbandBitsSymbol(SBs)] = modulationTable_QPSK((widebandSINR));
                elseif systemParameters.ABS == 2 && systemParameters.RPABSoffset == 3 && flaggedCH == 1
                    [subbandSINRTargets(SBs),subbandBitsSymbol(SBs)] = modulationTable_16QAM((widebandSINR));
                else
                    if isfield(systemParameters,'QAM256')
                        [subbandSINRTargets(SBs),subbandBitsSymbol(SBs)] = modulationTable_256QAM((widebandSINR));
                    else
                        [subbandSINRTargets(SBs),subbandBitsSymbol(SBs)] = modulationTable((widebandSINR));
                    end
                end
            end
            SINRtargetsCQI(subbandRBsIndex{SBs}) = subbandSINRTargets(SBs).*ones(1,length(subbandRBsIndex{SBs}));
            bitsSymbolsCQI(subbandRBsIndex{SBs}) = subbandBitsSymbol(SBs).*ones(1,length(subbandRBsIndex{SBs}));
        end
    elseif WAT == 1 % LiFi AP
        err('There is no support for UE selected subband CQI reporting at 802.11ax')
    end
elseif systemParameters.CQIreportType == 230 % Aperiodic Mode 3-0
    if WAT == 0 % eNB
        %% eNB selected subband CQI reporting
        % For 15 MHz and 20 MHz channels (#RBs 75 and 100, respectively):
        %   o Number of Subbands (SB)   = 9 for 15MHz and 12 for 20 MHz
        %   o Number of RBs per Subband = 8
        % UE reports one CQI for each subband
        % Initialize function outputs: SINR targets and bit/symbol
        SINRtargetsCQI = -Inf(1,length(RBs));
        bitsSymbolsCQI = zeros(1,length(RBs));
        % Find allowed RB index
        allowedRBsIndex = find(RBs==1);
        % Find total number of allowed RBs
        totalRBs = length(allowedRBsIndex);
        % Calculate average CQI for subband
        for SBs = 1:floor(totalRBs/8) % #subbands = floor(total#RBs / #RBsPerSubband)
            if SBs ~= floor(totalRBs/8)
                subbandRBsIndex = allowedRBsIndex(((SBs-1)*8+1):1:(SBs*8));
                avgSINR(SBs) = currentSINR(subbandRBsIndex)*ones(8,1)./8;
            else % 12th(9th) subband will have +4(+3) missing RBs from 100(75)/8 -- 20MHz(15MHz)
                subbandRBsIndex = allowedRBsIndex(((SBs-1)*8+1):1:totalRBs);
                avgSINR(SBs) = currentSINR(subbandRBsIndex)*ones(8+(totalRBs-SBs*8),1)./(8+(totalRBs-SBs*8));
            end
            if isfield(systemParameters,'woModRPABS')
                if systemParameters.woModRPABS == 1
                    if isfield(systemParameters,'QAM256')
                        [subbandSINRTargets(SBs),subbandBitsSymbol(SBs)] = modulationTable_256QAM((avgSINR(SBs)));
                    else
                        [subbandSINRTargets(SBs),subbandBitsSymbol(SBs)] = modulationTable((avgSINR(SBs)));
                    end
                else
                    if systemParameters.ABS == 2 && systemParameters.RPABSoffset == 6 && flaggedCH == 1
                        [subbandSINRTargets(SBs),subbandBitsSymbol(SBs)] = modulationTable_QPSK((avgSINR(SBs)));
                    elseif systemParameters.ABS == 2 && systemParameters.RPABSoffset == 3 && flaggedCH == 1
                        [subbandSINRTargets(SBs),subbandBitsSymbol(SBs)] = modulationTable_16QAM((avgSINR(SBs)));
                    else
                        if isfield(systemParameters,'QAM256')
                            [subbandSINRTargets(SBs),subbandBitsSymbol(SBs)] = modulationTable_256QAM((avgSINR(SBs)));
                        else
                            [subbandSINRTargets(SBs),subbandBitsSymbol(SBs)] = modulationTable((avgSINR(SBs)));
                        end
                    end
                end
            else
                if systemParameters.ABS == 2 && systemParameters.RPABSoffset == 6 && flaggedCH == 1
                    [subbandSINRTargets(SBs),subbandBitsSymbol(SBs)] = modulationTable_QPSK((avgSINR(SBs)));
                elseif systemParameters.ABS == 2 && systemParameters.RPABSoffset == 3 && flaggedCH == 1
                    [subbandSINRTargets(SBs),subbandBitsSymbol(SBs)] = modulationTable_16QAM((avgSINR(SBs)));
                else
                    if isfield(systemParameters,'QAM256')
                        [subbandSINRTargets(SBs),subbandBitsSymbol(SBs)] = modulationTable_256QAM((avgSINR(SBs)));
                    else
                        [subbandSINRTargets(SBs),subbandBitsSymbol(SBs)] = modulationTable((avgSINR(SBs)));
                    end
                end
            end
            SINRtargetsCQI(subbandRBsIndex) = subbandSINRTargets(SBs).*ones(1,length(subbandRBsIndex));
            bitsSymbolsCQI(subbandRBsIndex) = subbandBitsSymbol(SBs).*ones(1,length(subbandRBsIndex));
        end
    elseif WAT == 1 % LiFi AP
        err('There is no support for UE selected subband CQI reporting at 802.11ax')
    end
end
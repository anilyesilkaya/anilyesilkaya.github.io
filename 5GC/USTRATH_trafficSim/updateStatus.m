function [UE, eNB, LED] = updateStatus(UE, eNB, LED, actualTTI, dataRate, sessionTimeOut, WAT)
% This function updates the status of LiFi AP, eNB and UE.
% (i) If one of the active users is fully downloaded the requested content,
%     the user will be removed from the scheduling queue and the served
%     content will be flagged as suitable to cache in the next TTIs.
% (ii)Download finish time and latency performance will be recorded.
%
% Written by Tezcan Cogalan, UoE, 14/03/2020
%
% Update - 25/03/2020
% Data rate is calculated as bit per second and it needs to be
% converted to bit per millisecond level in order to obtain rate per TTI of
% 1 ms level. Therefore, dataRate is updated in each
% TTI with dataRate./1e3 bits.
%
% Update - 25/03/2020
% if the user has not been served until the session time out duration, it
% will be:
% (i)  dropped if the service is requested from eNB; or 
% (ii) handover to eNB if the service is requested from LiFi AP
%
%
%%
% Find active user set
if WAT == 0
    activeUsers = UE.activeUsers_eNB;
elseif WAT == 1
    activeUsers = UE.activeUsers_LAP;
end

for u = activeUsers
    eNBindex = UE.connectedBS(u);
    LEDindex = UE.connectedAP(u);
    % Obtain achieved data rate of the users
    totalWATdataRate = 0;
    if UE.requestTime(u) == -Inf
        asd=1;
        error('Request time cannot be -Inf');
        continue
    end
    for t=UE.requestTime(u):actualTTI
        if isempty(dataRate{t})
            dataRate{t} = zeros(length(UE.x),1);
        end
        % update total data rate [bits per millisecond] to represent TTI
        totalWATdataRate = totalWATdataRate + dataRate{t}(u)./1e3;
    end
    UE.downloadedFileSize(u) = totalWATdataRate;
    UE.downloadedFileSize_scheduler(u) = UE.downloadedFileSize(u);
    if totalWATdataRate == 0 && actualTTI-UE.requestTime(u) >= sessionTimeOut
        % Drop only one user at a TTI
        if WAT == 0 && sum(UE.eNBsessionDrop(:,actualTTI)) == 0
            % Flag session drop data for the user u and TTI actualTTI
            UE.eNBsessionDrop(u,actualTTI) = 1;
            % Remove the user u from the active users list of eNB
            UE.activeUsers_eNB(UE.activeUsers_eNB == u) = [];
            % Reset its scheduling metric
            eNB.Smetric{eNBindex}(eNB.connectedUE{eNBindex}==u) = -Inf;
            % Reset request time record and user's active information
            UE.activeBSs(u) = 0;
            UE.requestTime(u) = -Inf;
            UE.enabled(u) = 0;
        elseif WAT == 1 && sum(UE.LAPsessionDrop(:,actualTTI)) == 0
            % Flag session drop data for the user u and TTI actualTTI
            UE.LAPsessionDrop(u,actualTTI) = 1;
            % Remove the user u from the active users list of LAP
            UE.activeUsers_LAP(UE.activeUsers_LAP == u) = [];
            % Add the user u to the active users list of eNB
            UE.activeUsers_eNB = [UE.activeUsers_eNB, u];
            % Reset its scheduling metric
            LED.Smetric{LEDindex}(LED.connectedUE{LEDindex}==u) = -Inf;
            UE.activeLEDs(u) = 0;
            % Update request time for correct latency calculation for eNB
            UE.requestTime(u) = actualTTI;
            % Update eNB scheduling information
            eNB.numEvent(eNBindex) = eNB.numEvent(eNBindex)+1;
            eNB.Smetric{eNBindex}(eNB.connectedUE{eNBindex}==u) = Inf;
            UE.activeBSs(u) = eNBindex;
        end
        % Reset request time record and user's active information
        UE.downloadedFileSize(u) = 0;
        UE.downloadedFileSize_scheduler(u) = 0;
    end
    % If the total achieved rate is higher then the content size, the user
    % can be removed from the scheduling queue
    if totalWATdataRate >= UE.selectedContentSize(u)
        % Remove the user from the scheduler list and record performance
        % data
        UE.requireResources(u) = 0;
        if WAT == 0
            eNB.Smetric{eNBindex}(eNB.connectedUE{eNBindex}==u) = -Inf;
            UE.activeUsers_eNB(UE.activeUsers_eNB==u) = [];
            % Flag the requested content as can be cached at the LiFi
            % AP in the next TTIs
            eNB.servedContent(u,actualTTI) = UE.selectedContent(u);
            UE.activeBSs(u) = 0;
        elseif WAT == 1
            LED.Smetric{LEDindex}(LED.connectedUE{LEDindex}==u) = -Inf;
            UE.activeUsers_LAP(UE.activeUsers_LAP==u) = [];
            UE.activeLEDs(u) = 0;
        end
        % Record download finish time
        UE.servedTime(u) = actualTTI;
        % Calculate latency - servedTime - requestTime
        UE.latency{u} = [UE.latency{u}, ( UE.servedTime(u) - UE.requestTime(u) ) + 1];
        % Record latency data based on considered WAT
        if WAT == 0
            UE.eNBlatency{u} = UE.latency{u};
        elseif WAT == 1
            UE.LAPlatency{u} = UE.latency{u};
        end
        % Reset request time record and user's active information
        UE.requestTime(u) = -Inf;
        UE.enabled(u) = 0;
        UE.downloadedFileSize(u) = 0;
        UE.downloadedFileSize_scheduler(u) = 0;
    end
end

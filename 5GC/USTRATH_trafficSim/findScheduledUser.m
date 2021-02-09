function [scheduledUser, connectedBS] = findScheduledUser(candidateUsers,MSs,WAT)
% This function chooses a user from the candidate user list to be scheduled
%
% INPUT:
%       candidateUsers  : list of users who maximize scheduling objective
%       MSs             : Struct for users
% OUTPUT:
%       scheduledUser   : Chosen user to be scheduled
%       connectedBS     : eNB index where scheduled user is connected to
%
% Written by Tezcan Cogalan, UoE, 06/10/2016
%
% Update - 29/11/2019
% Parameter "WAT" is added to decide wireless access technology when UE
% related information is checked/updated - for example: connected BS or
% LiFi AP or WiFi AP
% WAT = 0 -> eNB
% WAT = 1 -> LiFi AP

if isempty(candidateUsers)
    scheduledUser = [];
    connectedBS = [];
elseif length(candidateUsers) == 1
    scheduledUser = candidateUsers;
    if WAT == 0
        connectedBS = MSs.connectedBS(scheduledUser);
    elseif WAT == 1
        connectedBS = MSs.connectedAP(scheduledUser);
    end
else
    scheduledUser = candidateUsers(randi(length(candidateUsers)));
    if WAT == 0
        connectedBS = MSs.connectedBS(scheduledUser);
    elseif WAT == 1
        connectedBS = MSs.connectedAP(scheduledUser);
    end
end
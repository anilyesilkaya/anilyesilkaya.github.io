function [bitsSymbol, SINRTargets, MSs, BSs, failedRBs, allocation, currentSINR] = commonMCSassignment(simParams, MSs, BSs, TTIindex, bitsSymbol, SINRTargets, ...
    allocation, currentSINR, WAT)
% This function assigns single Modulation and Coding Scheme (MCS) index to
% all allocated RBs for a user. MCS index which achieves maximum data rate
% under 10% BLER constraint is chosen to be used for all allocated RBs for
% a user.
%
% Written by Tezcan Cogalan, UoE, November 2016
%
% Update - 11/03/2020
% MSs.achievedRate is modified to be WAT-specific. For further details, see
% log of updates in calculateRate.m file
%
failedRBs = cell(1,length(BSs.x));
for bs = 1:size(allocation,1)
    % Find allocated users at eNB bs
    users = unique(allocation(bs,:));
    users(users==0) = []; % skip 0 as it is not a user index
    for k = users
        % Find allocated RBs to user k
        RBs = find(allocation(bs,:) == k);
        % Find MCS index of the allocated RBs
        MCS = unique(bitsSymbol(k,RBs));
        if length(MCS) == 1
            continue
        else
            % Sort MCSs in descending order
            sortedMCS = sort(MCS,'descend');
            % Calculate achievable rate for each MCS index to find which one
            % achieves the maximum under 10% BLER constraint;
            % NOTE: higher MCS may achieve lower rate than lower MCSs - due to number of RBs 
            supportedRate = zeros(size(sortedMCS));
            BLER = zeros(size(sortedMCS));
            for r = 1:length(sortedMCS)
                supportedRate(r) = sortedMCS(r)*sum(logical(bitsSymbol(k,RBs)>=sortedMCS(r)));
                BLER(r) = sum(logical(bitsSymbol(k,RBs)<sortedMCS(r)))/length(RBs);
            end
            % Find MCS index which provides maximum supported rate
            [~,MCSindex] = max(supportedRate);
            % Check the selected MCSindex achieves BLER constraint or not
            if BLER(MCSindex) > 0.1 % if not, release RBs with smaller MCS index
               % Set currentSINR (bitsSymbol will be 0 and SINRTargets will be -Inf) to 0 to mitigate allocating failed RBs to the same user again
                failedRBindex = RBs(logical(bitsSymbol(k,RBs) < sortedMCS(MCSindex)));
                currentSINR(k,failedRBindex) = 0;
                failedRBs{bs} = [failedRBs{bs}, failedRBindex];
                allocation(bs,failedRBs{bs}) = 0;
            end
            % Update bitsSymbol to use common MCS assignment
            usableRBs = RBs(logical(bitsSymbol(k,RBs) >= sortedMCS(MCSindex))); % Used RBs after relasing the failed ones
            bitsSymbol(k,usableRBs) = sortedMCS(MCSindex);
            SINRTargets(k,usableRBs) = min(SINRTargets(k,usableRBs));
            % Reset achieved user rate for the given TTIindex
            if WAT == 0
                MSs.eNBachievedRate(k,TTIindex) = 0;
            elseif WAT == 1
                MSs.LAPachievedRate(k,TTIindex) = 0;
            end
            % Update BSs.Smetric based on the new achievable rate by
            % considering all allocated RBs - RBsInRBG is equal 1 due
            % to considering all allocated RBs in instantRate calculation
            [~, MSs, BSs] = calculateRate(MSs, BSs, k, currentSINR, ...
                SINRTargets, bitsSymbol, simParams, TTIindex, bs, usableRBs, 1, WAT);
        end
    end
end
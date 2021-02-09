function [LED] = updateLiFiAPcache(LED,eNB,file,TTIindex,LEDcacheSizeBits,LEDindex)
% This function updates LED cache based on the popularity distribution of
% the demanded content at TTI-2 due to the assumption that a content
% delivered from eNB to UE at TTI i can be uploaded to LiFi AP at the TTI
% i+1 and will be available for LiFi AP to serve the content at TTI i+2.
%
% The LiFi AP cache is going to be updated based on Least Frequently Used
% (LFU) approach.
%
% Written by Tezcan Cogalan, UoE, 14/03/2020

% LEDcacheSizeBits = systemParameters.cacheSizeBits;
% clear eNBservedContent popi servedContent servedContentList popiIndex sortedPopi


%% Find served content to the users that are connected to the LiFi AP t at TTI-2
for t=LEDindex
    % Save current LED cache data
    LED.currentCache{t}(TTIindex,:) = LED.cachedFile(t,:);
    eNBservedContent = reshape(eNB.servedContent(LED.connectedUE{t},TTIindex-2),1,[]);
    eNBservedContent(eNBservedContent==0) = [];
    % Index already cached contents
    LAPcachedContent = find(LED.cachedFile(t,:)>0);
    % Obtain their demand frequency - popularity within LiFi AP
    LAPcontentPopularity = [];
    for lc=LAPcachedContent
        if LED.requestedFileCount(t,lc) > 0
            LAPcontentPopularity = [LAPcontentPopularity, repmat(lc,1,LED.requestedFileCount(t,lc))];
        else
            LAPcontentPopularity = [LAPcontentPopularity, lc];
        end
    end
    % Obtain the overall available content
    servedContent = [eNBservedContent,LAPcontentPopularity];
    % Obtain a list for available contents
    servedContentList = unique(servedContent);
    %% Obtain popularity of the served content
    % First, consider an empty cache for LiFi AP t
    LED.cachedFile(t,:) = 0;
    % Calculate content popularity
    for c=1:length(servedContentList)
        popi(c) = sum(logical(servedContent==servedContentList(c)));
    end
    % Sort the contents according to their popularity
    [sortedPopi,popiIndex] = sort(popi,'descend');
    %% Cache content if there is enough storage space
    for f=servedContentList(popiIndex)
        % Obtain LiFi AP free storage space
        alreadyCachedContent = logical(LED.cachedFile(t,:)>0);
        cacheFilledSpace = sum(file.sizeBits(alreadyCachedContent));
        cacheFreeSpace = LEDcacheSizeBits - cacheFilledSpace;
        % If there is enough space, store content f
        if ( cacheFreeSpace >= file.sizeBits(f) )
            LED.cachedFile(t,f) = 1;
        end
    end
    clear cacheFreeSpace alreadyCachedContent cacheFilledSpace servedContent servedContentList ...
        sortedPopi popiIndex c LAPcontentPopularity f LAPcachedContent lc eNBservedContent popi
end

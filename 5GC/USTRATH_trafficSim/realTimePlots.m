
if isempty(eNBdataRate{i})
    GPP = [GPP, zeros(20,1)];
else
    if length(eNBdataRate{i}) < actualTTI-1
        GPP = [GPP, zeros(20,1)];
    else
        GPP = [GPP,eNBdataRate{i}{actualTTI-1}'];
    end
end
subplot(1,3,1)
b = bar3(GPP./1e6);
drawnow
colorbar

for kb = 1:length(b)
    zdata = b(kb).ZData;
    b(kb).CData = zdata;
    b(kb).FaceColor = 'interp';
end

if isempty(LAPdataRate{i})
    LP = [LP,zeros(20,1)];
else
    if length(LAPdataRate{i}) < actualTTI-1
        LP = [LP,zeros(20,1)];
    else
        LP = [LP,LAPdataRate{i}{actualTTI-1}'];
    end
end
subplot(1,3,2)
c = bar3(LP./1e6);
drawnow
colorbar

for kc = 1:length(c)
    zdata = c(kc).ZData;
    c(kc).CData = zdata;
    c(kc).FaceColor = 'interp';
end

cch = [cch,LED.cachedFile'];
subplot(1,3,3)
ch = bar3(cch);
drawnow
colorbar

for kch = 1:length(ch)
    zdata = ch(kch).ZData;
    ch(kch).CData = zdata;
    ch(kch).FaceColor = 'interp';
end

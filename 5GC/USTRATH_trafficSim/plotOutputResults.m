% plot output figures
colors = [0 0 0; 1 0 0; 0 0 1; 0 1 0]; % black; red; blue; green
%% Plot latency
overallLatency = [];
for u=1:size(UE.latency,1)
    overallLatency = [overallLatency, UE.latency{u}];
end
figure;
h1 = cdfplot(overallLatency);
h1.DisplayName = 'Overall latency';
h1.LineWidth = 2;
h1.Color = colors(1,:);

% Plot eNB latency
eNBlatency = [UE.eNBlatency{:}];
hold on;
h2 = cdfplot(eNBlatency);
h2.DisplayName = 'eNB latency';
h2.LineWidth = 2;
h2.Color = colors(2,:);

% Plot LiFi latency
LAPlatency = [UE.LAPlatency{:}];
hold on;
h3 = cdfplot(LAPlatency);
h3.DisplayName = 'LiFi latency';
h3.LineWidth = 2;
h3.Color = colors(3,:);

xlabel('Latency [ms]','interpreter','latex');
title('')
legend
set(findall(gcf,'-property','FontSize'),'FontSize',18)
set(findall(gcf,'-property','FontName'),'FontName','Times New Roman')
set(findall(gcf,'-property','interpreter'),'interpreter','latex')
set(gca,'TickLabelInterpreter','latex')

%% Plot achieved data rate for each technology
eNBrate = reshape(UE.eNBachievedRate,1,[]);
eNBrate(eNBrate==0) = [];

LAPrate = reshape(UE.LAPachievedRate,1,[]);
LAPrate(LAPrate==0) = [];

figure;hold on;
h4 = cdfplot(eNBrate./1e6);
h4.DisplayName = 'eNB';
h4.LineWidth = 2;
h4.Color = colors(1,:);

h5 = cdfplot(LAPrate./1e6);
h5.DisplayName = 'LiFi AP';
h5.LineWidth = 2;
h5.Color = colors(2,:);
xlabel('Achieved rate [Mbps]');
title('');
legend
set(findall(gcf,'-property','FontSize'),'FontSize',18)
set(findall(gcf,'-property','FontName'),'FontName','Arial')
set(findall(gcf,'-property','interpreter'),'interpreter','latex')
set(gca,'TickLabelInterpreter','latex')
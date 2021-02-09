%% Plot location of the users and APs
APradius = systemParameters.roomDim(1)/(2*sqrt(systemParameters.Nt));
figure;
plot(APlocations(:,1),APlocations(:,2),'r^ ','LineWidth',1.5,'MarkerSize',8);hold on;
plot(userLocations(:,1),userLocations(:,2),'ko ','LineWidth',1.5,'MarkerSize',4);
xlim([-systemParameters.roomDim(1)/2 systemParameters.roomDim(1)/2]);
ylim([-systemParameters.roomDim(2)/2 systemParameters.roomDim(2)/2]);
xticks(-systemParameters.roomDim(1)/2:2*APradius:systemParameters.roomDim(1)/2);
yticks(-systemParameters.roomDim(2)/2:2*APradius:systemParameters.roomDim(2)/2);
grid on
xlabel('x-axis [m]');ylabel('y-axis [m]');
legend('AP','User');
set(findall(gcf,'-property','FontSize'),'FontSize',18)
set(findall(gcf,'-property','FontName'),'FontName','Arial')
set(findall(gcf,'-property','interpreter'),'interpreter','latex')
set(gca,'TickLabelInterpreter','latex')
hold on;
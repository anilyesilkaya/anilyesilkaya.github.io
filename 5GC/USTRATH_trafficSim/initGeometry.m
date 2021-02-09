function [userLocations, APlocations, eNBlocations] = initGeometry(systemParameters)
% Randomly distribute users - a total of #AP x # user per AP
totalUserNumber = systemParameters.Nt*systemParameters.numUserPerAP;
x_dim = [-systemParameters.roomDim(1)/2:systemParameters.gridSize:systemParameters.roomDim(1)/2]; % [m]
y_dim = [-systemParameters.roomDim(2)/2:systemParameters.gridSize:systemParameters.roomDim(2)/2]; % [m]

userLocations = [randsrc(totalUserNumber,1,x_dim),...
    randsrc(totalUserNumber,1,y_dim),...
    systemParameters.RxHeight.*ones(totalUserNumber,1)];

% Locate access points
APradius = systemParameters.roomDim(1)/(2*sqrt(systemParameters.Nt));
APlocs = [-systemParameters.roomDim(1)/2+APradius:2*APradius:systemParameters.roomDim(1)/2-APradius];
APlocations = [reshape(repmat(APlocs,sqrt(systemParameters.Nt),1),[],1),...
    repmat(APlocs,1,sqrt(systemParameters.Nt))',...
    systemParameters.roomDim(3).*ones(systemParameters.Nt,1)];

% Also randomly distribute eNBs/femtocells
x_dim_eNB = [-systemParameters.eNBrange/2:1:systemParameters.eNBrange/2];
eNBlocations = [randsrc(systemParameters.numBS,2,x_dim_eNB),...
    randsrc(systemParameters.numBS,1,systemParameters.BSheight)];
    
%% Plot location of the users and APs
% figure;
% plot(APlocations(:,1),APlocations(:,2),'r^ ','LineWidth',1.5,'MarkerSize',8);hold on;
% plot(userLocations(:,1),userLocations(:,2),'ko ','LineWidth',1.5,'MarkerSize',4);
% xlim([-systemParameters.roomDim(1)/2 systemParameters.roomDim(1)/2]);
% ylim([-systemParameters.roomDim(2)/2 systemParameters.roomDim(2)/2]);
% xticks(-systemParameters.roomDim(1)/2:2*APradius:systemParameters.roomDim(1)/2);
% yticks(-systemParameters.roomDim(2)/2:2*APradius:systemParameters.roomDim(2)/2);
% grid on
% xlabel('x-axis [m]');ylabel('y-axis [m]');
% legend('AP','User');
% set(findall(gcf,'-property','FontSize'),'FontSize',18)
% set(findall(gcf,'-property','FontName'),'FontName','Arial')
% set(findall(gcf,'-property','interpreter'),'interpreter','latex')
% set(gca,'TickLabelInterpreter','latex')
% hold on;
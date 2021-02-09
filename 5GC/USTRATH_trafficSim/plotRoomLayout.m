function plotRoomLayout(x,y,z)

dim = 10;
if length(x)>1
    xx = linspace(min(x),max(x),dim);
else
    xx = linspace(-x/2,x/2,dim);
end  
if length(y)>1
    yy = linspace(min(y),max(y),dim);
else
    yy = linspace(-y/2,y/2,dim);
end
if length(z)>1
    zz = linspace(min(z),max(z),dim);
else
    zz = linspace(0,z,dim);
end
figure;
% Draw z-axis
plot3(min(xx).*ones(1,dim),min(yy).*ones(1,dim),zz,'k','LineWidth',2);hold on;
plot3(min(xx).*ones(1,dim),max(yy).*ones(1,dim),zz,'k','LineWidth',2);
plot3(max(xx).*ones(1,dim),max(yy).*ones(1,dim),zz,'k','LineWidth',2);
plot3(max(xx).*ones(1,dim),min(yy).*ones(1,dim),zz,'k','LineWidth',2);
% Draw y-axis
plot3(min(xx).*ones(1,dim),yy,min(zz).*ones(1,dim),'k','LineWidth',2);
plot3(min(xx).*ones(1,dim),yy,max(zz).*ones(1,dim),'k','LineWidth',2);
plot3(max(xx).*ones(1,dim),yy,min(zz).*ones(1,dim),'k','LineWidth',2);
plot3(max(xx).*ones(1,dim),yy,max(zz).*ones(1,dim),'k','LineWidth',2);
% Draw x-axis
plot3(xx,min(yy).*ones(1,dim),min(zz).*ones(1,dim),'k','LineWidth',2);
plot3(xx,min(yy).*ones(1,dim),max(zz).*ones(1,dim),'k','LineWidth',2);
plot3(xx,max(yy).*ones(1,dim),min(zz).*ones(1,dim),'k','LineWidth',2);
plot3(xx,max(yy).*ones(1,dim),max(zz).*ones(1,dim),'k','LineWidth',2);
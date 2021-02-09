function [incidenceAngle divergenceAngle distance] = calculateAngle(sourceDirection,receiverDirection,sourcePosition,receiverPosition)
% direction vector should contain x,y and z components.
% Ex: (x,y,z) = (cos(aX) cos(aY) cos(aZ))
% position vector should contain x,y and z components in meters

%% Calculate distance between two points
difLineVec      = sourcePosition - receiverPosition;
distance        = sqrt(difLineVec*difLineVec');

%% Calculate normalized distance between two points to use angle calculation
RS2RR           = (sourcePosition - receiverPosition)./distance;
RR2RS           = (receiverPosition - sourcePosition)./distance;

%% Calculate angle between two points
incidenceAngle  = acosd(dot(receiverDirection,RS2RR));
divergenceAngle = acosd(dot(sourceDirection  ,RR2RS));
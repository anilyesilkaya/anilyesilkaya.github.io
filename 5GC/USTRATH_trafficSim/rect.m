function [Rect ConcentratorGain]= rect(nominator,denominator,concGain,concIntRefInd)
% nominator: incidence Angle
% denominator: FOV
x = nominator/denominator;
if abs(x) <= 1
    Rect = 1;
    if concGain == 2
        ConcentratorGain = (concIntRefInd^2)/(sind(nominator)^2);
    elseif concGain == 1
        ConcentratorGain = 1;
    end
else
    Rect = 0;
    if concGain == 2
        ConcentratorGain = 0;
    elseif concGain == 1
        ConcentratorGain = 1;
    end
end

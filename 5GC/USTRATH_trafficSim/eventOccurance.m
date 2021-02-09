function [eventInterarrivalPoisson,eventOccurenceTime] = ...
    eventOccurance(lambda,eventNumber)
% simulates the occurrence of a given number of Poisson events
% lambda = 2;
% event_num = 1000;

eventInterarrivalPoisson(1) = 0.0;
eventInterarrivalPoisson(2:eventNumber+1) = - log ( rand ( eventNumber, 1 ) ) / lambda;
eventOccurenceTime(1:eventNumber+1) = cumsum ( eventInterarrivalPoisson(1:eventNumber+1) );

% disp(mean(w))
% disp(mean(t))
% figure;cdfplot(t);
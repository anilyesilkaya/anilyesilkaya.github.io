function [eventTime,occurance] = poissonArrivals(lambda,duration)
% This function generates arrivals (user requests) based on Poisson
% distribution with a rate specific for a given duration.
% Input
% -- lambda         : Poisson arrival rate
% -- duration       : Considered duration to observe events
% Output
% -- eventTime      : Represents time of each individual event/arrival
% -- occurance      : Represents time difference between two adjacent events

t_total = 0.0;
event = 0;
while ( t_total < duration )
    t = - log ( rand ( 1, 1 ) ) / lambda;
    event = event + 1;
    t_total = t_total + t;
    eventTime(event) = t_total;
    occurance(event) = t;
    %     fprintf ( 1, '  Event #%d occurs at time %g, after waiting %g\n', event, t_total, t )
end
% Round the ms values to have integer values
eventTime = round(eventTime);
occurance = round(occurance);

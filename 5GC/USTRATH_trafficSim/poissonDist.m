% function y = poissonDist(lambda,T)
clear all;clc

lambda = 3;
T = 10;
% for k=1:K
%     y(k) = (lambda^k) * exp(-lambda) ./ factorial(k);
% end

%% Generate all events in (0,K)
for i=1:1e3
    k = -log(rand)/lambda;
    n = 0;
    while k<T
        n = n+1;
        S(n) = k;
        k = k - log(rand)/lambda;
    end
    countN(i) = n;
    countS(i,:) = S(n);
end
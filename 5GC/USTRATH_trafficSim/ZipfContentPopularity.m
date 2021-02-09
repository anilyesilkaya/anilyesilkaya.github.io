function [file] = ZipfContentPopularity(numFiles,ZipfParameter,bitsPerFile)
% This function generates content popularity and size
% Input:
% -- numFiles       : number of files in the library.
% -- ZipfParameter  : considered Zipf parameter, \alpha.
% -- bitsPerFile    : number of bits per each content, either fixed size or
%                     random, please see systemParameters.randomFileSize
%                     value in the main code.
% Output:
% -- file           : Represents the content structure with its popularity
%                     and size in bits.
%
% Created by Tezcan Cogalan, UoE, October 2019.
%%
%% Zipf file popularity -> \psi * n^-\alpha ; where \psi = 1 / sum_n=1^N (n^-\alpha)
popularityConstant = 1/(sum( (1:numFiles).^(-ZipfParameter) ));
filePopularity = popularityConstant.*((1:numFiles).^(-ZipfParameter));
%% Create structure for files
file.sizeBits = bitsPerFile;
file.popularity = filePopularity;

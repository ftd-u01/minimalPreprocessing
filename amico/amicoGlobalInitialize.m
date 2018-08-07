clearvars, clearvars -global, clc

% AMICO code
addpath('/data/grossman/hcp/bin/AMICO/matlab')

% AMICO setup function lives here
addpath('/data/grossman/hcp/scripts/amico')

% Setup AMICO
AMICO_Setup

% Pre-compute auxiliary matrices to speed-up the computations
AMICO_PrecomputeRotationMatrices(); % NB: this needs to be done only once

%
% Initialization for AMICO
% Needs to be called before running AMICO functions
%

global AMICO_code_path AMICO_data_path CAMINO_path CONFIG
global niiSIGNAL niiMASK
global KERNELS bMATRIX

% Path definition: adapt these to your needs
% ==========================================
AMICO_code_path = '/data/grossman/hcp/bin/AMICO/matlab';
AMICO_data_path = '/data/grossman/hcp/amico';
CAMINO_path     = '/data/grossman/hcp/bin/camino/bin';
NODDI_path      = '/data/grossman/hcp/bin/noddi/NODDI_toolbox_v1.0';
SPAMS_path      = '/data/grossman/hcp/bin/spams-matlab';

addpath( genpath(NODDI_path) )
addpath( fullfile(SPAMS_path,'build') )
addpath( fullfile(AMICO_code_path,'kernels') )
addpath( fullfile(AMICO_code_path,'models') )
addpath( fullfile(AMICO_code_path,'optimization') )
addpath( fullfile(AMICO_code_path,'other') )
addpath( fullfile(AMICO_code_path,'vendor','NIFTI') )

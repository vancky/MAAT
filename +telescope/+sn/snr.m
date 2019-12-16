function [SN]=snr(varargin)
% Signal-to-Noise ratio calculator using full spectral components.
% Package: telescope.sn
% Description: Given the spectra of the source and background components,
%              calculate the S/N for PSF detection.
% Input  : * Arbitrary number of pairs of arguments: ...,keyword,value,...
%            where keyword are one of the followings:
% Output : - 
% License: GNU general public license version 3
%     By : Eran O. Ofek                    Nov 2019
%    URL : http://weizmann.ac.il/home/eofek/matlab/
% Example: [SN]=telescope.sn.snr
% Reliable: 
%--------------------------------------------------------------------------

RAD = 180./pi;


DefV.SN                   = 5;
DefV.Mag                  = 22.0;
DefV.FWHM                 = 12;     % FWHM [arcsec]
DefV.PSFeff               = 0.8;    % PSF efficiency
DefV.Aper                 = 33;     % [cm]
DefV.FL                   = 36;     % [cm]
DefV.PixSize              = 9.5;    % [micron]
DefV.RN                   = 3.5;    % [e-]
DefV.StrayLight           = 3.5.^2; % [e-]  per image/pix
DefV.DC                   = 1e-2;   % [e-/pix/s]
DefV.Gain                 = 2;      % [e-/ADU]
DefV.ExpTime              = 300;    % [s]
DefV.Nim                  = 3;
DefV.ClearAper            = 0.75;
DefV.Trans                = 1; %0.99.^8 .* 0.99.^4;
DefV.Reflection           = 1; %0.96;
DefV.QE                   = 1; %0.7;
DefV.TargetSpec           = 2e4;    % if given override Mag
DefV.BackSpec             = @telescope.sn.back_comp;    % per arcsec^2 | handle | AstSpec | matrix
DefV.BackCompFunPar       = {};
DefV.Ebv                  = 0.02;
DefV.Filter               = 'Req4m3';
DefV.FilterFamily         = 'ULTRASAT';
DefV.MagSys               = 'AB';
DefV.Wave                 = (1000:10:25000).';  % [ang]
DefV.InterpMethod         = 'linear';


%problem with target spec normalization 
%changing temp - and result doesn't make sense

if (numel(varargin)==1)
    % assume input is a structure (like DefV)
    InPar = varargin{1};
else
    InPar = InArg.populate_keyval(DefV,varargin,mfilename);
end

PixScale  = InPar.PixSize.*1e-4./InPar.FL .*RAD.*3600;

SN.PsfEffAreaAS  = 4.*pi.*(InPar.FWHM./2.35).^2;
SN.PsfEffAreaPix = SN.PsfEffAreaAS./(PixScale.^2);


if isa(InPar.BackSpec,'function_handle')
    InPar.BackSpec = InPar.BackSpec('PsfEffAreaAS',SN.PsfEffAreaAS,InPar.BackCompFunPar{:});
end
    

% extinction curve
% A_w = AstroUtil.spec.extinction(InPar.Ebv,InPar.Wave./1e4); % extinction per wave [mag]
    
% BackSpec = AstSpec(3);
% RAD=180./pi;
% [Spec]=ultrasat.zodiac_bck(220./RAD,66./RAD,[21 12 2024],'Wave',InPar.Wave);
% %InPar.BackSpec = [Spec.Wave,Spec.Spec];
% BackSpec(1).Wave = Spec.Wave;
% BackSpec(1).Int  = Spec.Spec;
% 
% [Res,ResEl]=ultrasat.Cerenkov('FluxOption','DailyMax_75flux');
% BackSpec(2).Wave   = Res.Lam;
% BackSpec(2).Int  = Res.IntFA./6;
% 
% %
% MagHost = 18; %16.5;
% SG = AstSpec.get_galspec('Gal_Sc.txt');
% SG.Wave(end+1) = 12000;
% SG.Int(end+1)  = 2e-14;
% 
% FactorHost = 10.^(-0.4.*(MagHost - synphot(SG,'SDSS','r','AB')));
% SG.Int = SG.Int.*FactorHost;
% synphot(SG,'SDSS','r','AB')
% % for any galaxy smaller than about 20''
% SG.Int = SG.Int./SN.PsfEffAreaAS;  % surface brightness
% BackSpec(3) = SG;
% 
% InPar.BackSpec = BackSpec;


Nwave = numel(InPar.Wave);
AperArea  = pi.*(InPar.Aper.*0.5).^2;




% get filter
if AstFilter.isAstFilter(InPar.Filter)
    Filter = InPar.Filter;
else
    if (ischar(InPar.Filter))
        Filter = AstFilter.get(InPar.FilterFamily,InPar.Filter);
        
    else
        % assume [central wave, full width]
        error('not available yet');
    end
end
Filter = interp(Filter,InPar.Wave);

% total aperture efficiency
Eta = InPar.ClearAper.*InPar.Trans.*InPar.Reflection.*InPar.QE;

% Total transmission of system as a function of wave
Trans        = [Filter.T(:,1), Filter.T(:,2).*Eta];


% get Target spectrum
if AstSpec.isastspec(InPar.TargetSpec)
    % [Ang, erg/cm^2/s/A]
    % interpolate over grid
    InPar.TargetSpec = interp(InPar.TargetSpec,InPar.Wave);
    TargetSpec = [InPar.TargetSpec.Wave, InPar.TagetSpec.Int];
else
    if numel(InPar.TargetSpec)==1
        % assume BB temperature
        AS = AstSpec.blackbody(InPar.TargetSpec,InPar.Wave);
        % [Ang, erg/cm^2/s/A]
        TargetSpec = [AS.Wave, AS.Int];
    else
        % assume matrix of spectrum
        % [Ang, erg/cm^2/s/A]
        % interpolate
        TargetSpec = [InPar.Wave, interp1(InPar.TargetSpec(:,1),InPar.TargetSpec(:,2),InPar.Wave,InPar.InterpMethod)];
    end
end

% Normalize TargetSpec to apparent magnitude
[Mag,Flag] = AstroUtil.spec.synphot(TargetSpec,InPar.FilterFamily,InPar.Filter,InPar.MagSys);
Factor    = 10.^(-0.4.*(Mag-InPar.Mag));
TargetSpec(:,2) = TargetSpec(:,2)./Factor;






% get background spectrum [erg/cm^2/s/Ang/arcsec^2]
% background options:
% AstSpec spectra of several background componts
% AB magnitude scalar - will construct a flat f_nu spectrum
% Matrix of spectrum
if AstSpec.isastspec(InPar.BackSpec)
    % [Ang, erg/cm^2/s/A]
    % combine multiple background spectra
    BackSpec = [InPar.Wave, zeros(Nwave,1)];
    SN.BackComp = AstSpec(size(InPar.BackSpec));
    for Ib=1:1:numel(InPar.BackSpec)
        Tmp = interp(InPar.BackSpec(Ib),InPar.Wave);
        BackSpec(:,2) = BackSpec(:,2) + Tmp.Int;
        
        % calculate the background component after transmission
        SN.BackComp(Ib) = Tmp;
        SN.BackComp(Ib).Int = SN.BackComp(Ib).Int.*Trans(:,2);  % erg/cm^2/s/Ang
    end
else
    if numel(InPar.BackSpec)==1
        % assume flat magnitude
        FluxBack = convert.flux(InPar.BackSpec,InPar.MagSys,'cgs/A',Filter.eff_wl,'A');
        % [Ang, erg/cm^2/s/A]
        BackSpec = [InPar.Wave, FluxBack.*ones(Nwave,1)];
        
        % calculate the background component after transmission
        SN.BackComp = BackSpec;
        SN.BackComp(:,2).*Trans(:,2);
    else
        % assume matrix of spectrum
        % [Ang, erg/cm^2/s/A]
        BackSpec = [InPar.Wave, interp1(InPar.BackSpec(:,1),InPar.BackSpec(:,2),InPar.Wave,InPar.InterpMethod)];
        
        % calculate the background component after transmission
        SN.BackComp = BackSpec;
        SN.BackComp(:,2).*Trans(:,2);
    end
end

% convert spectra from erg to photons
TargetSpecPh = [TargetSpec(:,1), convert.flux(TargetSpec(:,2),'cgs/A','ph/A',TargetSpec(:,1),'A')];
BackSpecPh   = [BackSpec(:,1),   convert.flux(BackSpec(:,2),  'cgs/A','ph/A',BackSpec(:,1),  'A')];   % per arcsec^2


SN.Signal = InPar.PSFeff.* InPar.Nim.*TargetSpecPh(:,2).*Trans(:,2).*AperArea.*InPar.ExpTime;  % [ph/ExpTime/Aper]
SN.Back   = InPar.Nim.* 4.*pi.*(InPar.FWHM./2.35).^2.*Trans(:,2).*BackSpecPh(:,2).*AperArea.*InPar.ExpTime;   % [ph/ExpTime/Aper]

SN.IntRN2    = InPar.Nim.* InPar.RN.^2.* SN.PsfEffAreaPix;
SN.IntDC     = InPar.Nim.* InPar.DC.*InPar.ExpTime .* SN.PsfEffAreaPix;
SN.IntGain   = InPar.Nim.* InPar.Gain.*0.3;
SN.IntStrayLight = InPar.Nim.*InPar.StrayLight;

% spectrum of total noise components


BackAS = BackSpecPh(:,2).*AperArea.*InPar.ExpTime;

FlagG = ~isnan(SN.Signal);

SN.IntSignal = trapz(InPar.Wave(FlagG), SN.Signal(FlagG));
SN.IntBack   = trapz(InPar.Wave(FlagG), SN.Back(FlagG));    % effective back per PSF
SN.IntBackAS = trapz(InPar.Wave(FlagG),BackAS(FlagG));      % background per sq arcsec


SN.TotalVar  = SN.IntBack + SN.IntRN2 + SN.IntDC + SN.IntGain + SN.IntStrayLight; 

SN.Mag          = InPar.Mag;
SN.SNR          = SN.IntSignal./sqrt(SN.TotalVar);
SN.FracVar.Back = SN.IntBack./SN.TotalVar;
SN.FracVar.RN   = SN.IntRN2./SN.TotalVar;
SN.FracVar.DC   = SN.IntDC./SN.TotalVar;
SN.FracVar.Gain = SN.IntGain./SN.TotalVar;
SN.FracVar.StraLight = SN.IntStrayLight./SN.TotalVar;

LimSignal       = InPar.SN.*sqrt(SN.TotalVar)./SN.IntSignal;
SN.LimMag       = InPar.Mag - 2.5.*log10(LimSignal);




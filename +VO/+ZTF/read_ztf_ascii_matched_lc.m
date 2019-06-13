function [Data,ColCell]=read_ztf_ascii_matched_lc(File,varargin)
% Read ZTF ascii file of matched light curves
% Package: VO.ZTF
% Description: Read ZTF ascii file of matched light curves.
%              Optionally save the data and meta data in an HDF5 file.
%              The matched light curves files and description are
%              available from:
%              https://www.ztf.caltech.edu/page/dr1#12c
% Input  : - A string of the txt file name or a numeric scalar of
%            the ZTF field ID.
%          * Arbitrary number of pairs of arguments: ...,keyword,value,...
%            where keyword are one of the followings:
%            'FileNamePrefix' - Default is 'field'.
%            'FileNameSuffix' - Default is '.txt'.
% Output : - Structure array of all sources with their light curves.
%            Available fields are:
%            'ID' - Source ID
%            'Nep' - Number of epochs
%            'FilterID' - Filter ID
%            'Field' - ZTF field index.
%            'RcID' - Readout channel ID (CCD/quad) 0 to 63
%            'RA' - J2000.0 R.A. [deg] of source in reference image.
%            'Dec' - J2000.0 Dec. [deg] of source in reference image.
%            'LC' - Array of source lightcurve [columns X times]
%          - Cell array of columns in the LC array.
% License: GNU general public license version 3
%     By : Eran O. Ofek                    Jun 2019
%    URL : http://weizmann.ac.il/home/eofek/matlab/
% Example: [Data,ColCell]=VO.ZTF.read_ztf_ascii_matched_lc(868);
% Reliable: 2
%--------------------------------------------------------------------------

RAD = 180./pi;

DefV.FileNamePrefix       = 'field';
DefV.FileNameSuffix       = '.txt';
DefV.H5_FileName          = '';
DefV.H5_DataSetInd        = '/IndAllLC';  
DefV.H5_DataSetLC         = '/AllLC';  
InPar = InArg.populate_keyval(DefV,varargin,mfilename);


if (ischar(File))
    FileName = File;
elseif (isnumeric(File))
    F = dir(sprintf('%s%06d*%s',InPar.FileNamePrefix,File,InPar.FileNameSuffix));
    if (isempty(F))
        error('File name constructed from field ID was not found');
    end
    if (numel(F)>1)
        warnning('Multiple files were found for field ID, reading first');
    end
    FileName = F(1).name;
else
    error('First argument File name should be string or numeric');
end
    
FID = fopen(FileName,'r');

ColCell = {'HMJD','Mag','MagErr','ColorCoef','Flags'};
Col     = cell2struct(num2cell(1:1:numel(ColCell)),ColCell,2);

Ncol    = numel(ColCell);
%catflags: Photometric/image quality flags encoded as bits (Section 9b).
%            In particular, you will always want to exclude observation epochs
%            affected by clouds and/or the moon. These epochs have catflags = 32768
%            (decimal bit 15).
            
Iobj = 0;
while ~feof(FID)
    Iobj = Iobj + 1;
    Header = fscanf(FID,'%s %ld %d %d %d %d %f %f\n',8);
    Nep = Header(3);
    LC = fscanf(FID,'%f %f %f %f %d\n',5.*Nep);
    
    Data(Iobj).ID       = Header(2);
    Data(Iobj).Nep      = Nep;
    Data(Iobj).FilterID = Header(4);
    Data(Iobj).Field    = Header(5);
    Data(Iobj).RcID     = Header(6);  % readout channel ID (CCD/quad 0..63)
    Data(Iobj).RA       = Header(7);  % RA in ref
    Data(Iobj).Dec      = Header(8);
    Data(Iobj).LC       = reshape(LC,Ncol,Nep);
    
end

fclose(FID);

% Save the data in HDF5 file
if ~isempty(InPar.H5_FileName)
    Nobj = numel(Data);
    Nep = [Data.Nep];
    I1  = cumsum([1,Nep]');
    I2  = [I1(2:end)-1; I1(end)+Nep(end)-1];
    
    MeanMag = nan(Nobj,1);
    StdMag  = nan(Nobj,1);
    RStdMag = nan(Nobj,1);
    MaxMag  = nan(Nobj,1);
    MinMag  = nan(Nobj,1);
    Chi2    = nan(Nobj,1);
    MaxPower= nan(Nobj,1);
    FreqMaxPower= nan(Nobj,1);
    
    FreqVec = (0:1./600:4)';
    
    Pool = parpool(12);
    
    tic;
    parfor Iobj=1:1:Nobj
        MeanMag(Iobj) = mean(Data(Iobj).LC(Col.Mag,:));
        
        StdMag(Iobj)  = std(Data(Iobj).LC(Col.Mag,:));
      
        RStdMag(Iobj) = Util.stat.rstd(Data(Iobj).LC(Col.Mag,:).');
       
        MaxMean(Iobj) = max(Data(Iobj).LC(Col.Mag,:)) - MeanMag(Iobj);
        MinMean(Iobj) = MeanMag(Iobj) - min(Data(Iobj).LC(Col.Mag,:));
        Chi2(Iobj)    = sum((Data(Iobj).LC(Col.Mag,:) - MeanMag(Iobj)).^2./Data(Iobj).LC(Col.MagErr,:).^2);
        
        
        P = timeseries.period_normnl(Data(Iobj).LC( [Col.HMJD, Col.Mag],:).',FreqVec);
        [MaxPower(Iobj),MaxInd] = max(P(:,2));
        FreqMaxPower(Iobj) = FreqVec(MaxInd);
        
    end
    toc
    
    delete(gcp('nocreate'))
    
    % RA Dec I1, I2, Nep, StarIndInFile, ID, FilterID, Field, RcID,
    % MeanMag, StdMag, RStdMag, MaxMag, MinMag, Chi2, MaxPower,
    % FreqMaxPower
    ColCellInd = {'RA','Dec','I1','I2','Nep','StarIndInFile', 'ID',...
                  'FilterID','Field','RcID',...
                  'MeanMag', 'StdMag', 'RStdMag', 'MaxMag', 'MinMag',...
                  'Chi2', 'MaxPower', 'FreqMaxPower'};
    ColInd = cell2struct(num2cell(1:1:numel(ColCellInd)),ColCellInd,2);

    IndAllLC = [ [Data.RA].'./RAD, [Data.Dec].'./RAD, I1, I2, [Data.Nep].',...
                 (1:1:Nobj).', [Data.ID].', [Data.FilterID].',...
                 [Data.Field].', [Data.RcID].',...
                 MeanMag, StdMag, RStdMag, MaxMag,MinMag, Chi2, MaxPower, FreqMaxPower];
                 
                 
    KeysInd = [ColCellInd', num2cell(1:1:numel(ColCellInd))'];
    HDF5.save(IndAllLC,InPar.H5_FileName,InPar.H5_DataSetLC,KeysInd);
    
    KeysLC = [ColCell', num2cell(1:1:numel(ColCell))'];
    HDF5.save(LC,InPar.H5_FileName,InPar.H5_DataSetLC,KeysLC);

end

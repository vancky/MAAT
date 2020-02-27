function Cat=build_obsid_cat(varargin)
% Construct a catalog of all Chandra observations
% Package: VO.Chandra
% Description: Construct a catalog of all Chandra observations by going
%              over the entire Chandra image archive.
% Input  : * Arbitrary number of pairs of arguments: ...,keyword,value,...
%            where keyword are one of the followings:
%            'AO'      - AO to download. Default is 'ao01'.
%            'GetInfo' - Get information [JD, RA, Dec] for each ObsID
%                        in addition to the OBSID and its location
%                        {true|false}. Default is true.
%           'Verbose'  - {true|false}. Default is true.
%           'OutType'  - Output type:
%                        'struct' - structure array.
%                        'AstCat' - AstCat object (default).
%           'SaveDir'  - Directory in which to save the catalog.
%                        If empty, then do not save.
%                        Default is '~/matlab/data/+cats/+X/'.
%           'SaveName' - File name in which to save the catalog.
%                        Default is 'ChandraObs_%s.mat', where %s is the AO.
% Output : - Structure array or AstCat object of all the Chandra observations.
% Tested : Matlab R2014a
%     By : Eran O. Ofek                    Jan 2015
%    URL : http://weizmann.ac.il/home/eofek/matlab/
% Example: Cat=VO.Chandra.build_obsid_cat('ao','ao10');
% Reliable: 2
%--------------------------------------------------------------------------

RAD = 180./pi;

DefV.AO       = 'ao01';
DefV.GetInfo  = true;
DefV.Verbose  = true;
DefV.OutType  = 'AstCat';
DefV.SaveDir  = '~/matlab/data/+cats/+X/';
DefV.SaveName = 'ChandraObs_%s.mat';  % with AO
DefV.ArchiveURL = 'https://cxc.cfa.harvard.edu/cdaftp/science/';

InPar = InArg.populate_keyval(DefV,varargin,mfilename);


Key2read = {'RA_NOM','DEC_NOM','ROLL_NOM','EXPOSURE','INSTRUME','GRATING','OBS_MODE','DATAMODE','OBSERVER','OBJECT','DATE-OBS','DATE-END','TSTART','TSTOP','MJDREF'};
Nkey = numel(Key2read);
    
ArchiveURL_AO = sprintf('%s%s/',InPar.ArchiveURL,InPar.AO);

% search directories for ObsID
[ListURL,IsDir,FileNames]=www.r_files_url(ArchiveURL_AO);
Nlist = numel(ListURL);
%Tmp = regexp(LL,'https://cxc.cfa.harvard.edu/cdaftp/science/(?<dir>.+)','names');
%MatchStr = sprintf('%s.+evt2.fits.+',ArchiveURL);
MatchStr = sprintf('%s.*oif.fits.*',ArchiveURL_AO);

%regexp(ListURL,'https://cxc.cfa.harvard.edu/cdaftp/science/.+evt2.fits.+','match')
Tmp = regexp(ListURL,MatchStr,'match');
FlagEvt = ~Util.cell.isempty_cell(Tmp);
ListEvt = ListURL(FlagEvt);
Nevt    = numel(ListEvt);

for Ievt=1:1:Nevt
    [Ievt, Nevt]
    Evt2url = ListEvt{Ievt};
    Tmp = regexp(Evt2url,'/','split');
    EvtFileName = Tmp{end};
    Data(Ievt).AO    = Tmp{end-3};
    Data(Ievt).Cat   = Tmp{end-2};
    Data(Ievt).ObsID = str2double(Tmp{end-1});
    Data(Ievt).oif_url = Evt2url;
    Data(Ievt).url     = Evt2url(1:end-8);
    
    try
        www.pwget({Evt2url});
    catch
        pause(120);
        www.pwget({Evt2url});
    end
    
    H = FITS.get_head(EvtFileName,2);
    delete(EvtFileName)
    
    for Ikey=1:1:Nkey
        
        FlagK = strcmp(H.Header(:,1),Key2read{Ikey});
        Val   = H.Header{FlagK,2};
        if ~isempty(strfind(Key2read{Ikey},'DATE'))
            Val = celestial.time.julday(Val);
        end
        % store data ins tructure
        KeyTmp = regexprep(Key2read{Ikey},'-','');
        Data(Ievt).(KeyTmp) = Val;
    end
    
    
    if (InPar.Verbose)
        fprintf('ObsID=%d   %d  %d\n',Data(Ievt).ObsID);
    end

end    


switch lower(InPar.OutType)
    case 'struct'
        % do nothing
    case 'astcat'
        Table = table([Data.RA_NOM].'./RAD,[Data.DEC_NOM].'./RAD,[Data.ROLL_NOM].',...
              [Data.ObsID].',{Data.AO}.',{Data.Cat}.',{Data.url}.',...
              [Data.EXPOSURE].',[Data.DATEOBS].',...
              Util.string.spacedel({Data.INSTRUME}).',Util.string.spacedel({Data.GRATING}).',...
              Util.string.spacedel({Data.OBS_MODE}).',Util.string.spacedel({Data.DATAMODE}).',...
              Util.string.spacedel({Data.OBJECT}).',Util.string.spacedel({Data.OBSERVER}).');
        
        ColCell = {'RA','Dec','Roll','ObsID','AO','Cat','URL','ExpTime','JD','Instrument','Grating',...
                   'ObsMode','DataMode','Object','Observer'};
        ColUnits = {'rad','rad','deg','','','','','s','JD','','','','','',''};
        Table.Properties.VariableNames =  ColCell ;
        Table.Properties.VariableUnits = ColUnits;
          
        Cat = AstCat;
        Cat.Cat = Table;
        Cat.ColCell = ColCell;
        Cat.ColUnits = ColUnits;
        Cat = colcell2col(Cat);
        Cat = sortrows(Cat,'Dec');
        Cat.Version = date;
        Cat.Source  = sprintf('VO.Chandra.build_obsid_cat AO=%s',InPar.AO);
        
    otherwise
        error('Unknown OutType option');
end


if (~isempty(InPar.SaveDir))
    PWD = pwd;
    cd(InPar.SaveDir)
    ChandraObs = Cat;
    SaveName = sprintf(InPar.SaveName,InPar.AO);
    save(SaveName,'ChandraObs','-v7.3');
    cd(PWD);
end
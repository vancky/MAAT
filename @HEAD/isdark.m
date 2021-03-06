function [IsDark,Res]=isdark(varargin)
%--------------------------------------------------------------------------
% isdark function                                              class/@HEAD
% Description: Check if HEAD/SIM objects are dark images.
%              The program can look for dark images in a set of SIM or HEAD
%              objects, using header keyword or/and file name. It also
%              check if the images are not saturated, and if the images
%              are similar (in difference or ratio) to a template image.
% Input  : - An HEAD object or a SIM object. For HEAD objects can look
%            for dark images only based on header keywords.
%          * Arbitrary number of pairs of arguments: ...,keyword,value,...
%            where keyword are one of the followings:
%            'TypeKeyVal' - The value of the IMTYPE like keyword in
%                           the header in case of a dark image.
%                           Either a string or a cell array of strings
%                           (i.e., multiple options).
%                           Default is {'dark','Dark','DARK'}.
%            'TypeKeyDic' - IMTYPE keyword names. If empty use the istype.m
%                           default which is:
%                           {'TYPE','IMTYPE','OBSTYPE','IMGTYP','IMGTYPE'}.
%                           Default is empty.
%            'FileNameStr'- Optional search for dark images based on file
%                           name. This is a substring that if contained
%                           in the file name then the image is a dark.
%                           If empty then do not use this option.
%                           Default is empty.
%            'FitDark'    - Fit median vs. exposure time. Default is true.
%            'StdFun'     - Function to use for the calculation of the
%                           global std of a SIM object {@std | @rstd}.
%                           Default is @rstd (slower than @std).
%            'GAIN'       - The detector gain [e-/ADU]. Either a numeric
%                           value or a string or a cell array of strings
%                           of possible header keywords containing the 
%                           detector gain.
%            'ExpTime'    - An exposure time [s] or astring or a cell array
%                           of strings containing the header keyword
%                           with the exposure time. 
%                           Default is {'AEXPTIME','EXPTIME'}.
%            'Nnoise'     - How many times the noise should we expect
%                           the median of the image from its expected
%                           value based on fitting the exptime with median
%                           of all candidate dark images. Default is 3.
%            'Template'   - A matrix or a SIM image containing a template
%                           image which will be compared with each input
%                           image.
%                           If empty then do not use template search.
%                           Default is empty.
%            'TemplateType'- The comparison with the template can either
%                           done by difference ('diff') or by ratio
%                           ('ratio'). Default is 'ratio'.
%            'TemplateNoise'- The image is a possible dark image if the
%                           global std of the comparison with the template
%                           is smaller than this value (in the native units
%                           of the image). Default is 30.
%            'CombType'   - The function tha will be used to combine all
%                           the dark search criteria {@all|@any}.
%                           Default is @all (i.e., requires that all the
%                           criteria are fullfilled).
%                           However, only active searches are being
%                           combined. For example, if 'Template' is empty
%                           then its results (false) will not be combined.
%            'SelectMethod'- Method by which to select the best keyword
%                           value. See getkey_fromlist.m for details.
%                           Default is 'first'.
% Output : - A vector of logical flags indicating if each image is a
%            candidate dark image, based on the combined criteria.
%          - A structure array with additional information.
%            The following fields are available:
%            .IsDarkKey - IsDark based on IMTYPE header keyword
%            .IsDarkFN  - IsDark based on file name.
%            .IsDarkStd - IsDark based on fitting the median value with
%                         exposure time and looking for non-outliers.
%            .IsDarkTempStd - IsDark based on comparison with template.
% License: GNU general public license version 3
% Tested : Matlab R2015b
%     By : Eran O. Ofek                    Apr 2016
%    URL : http://weizmann.ac.il/home/eofek/matlab/
% Example: [IsDark,R]=isdark(S);
% Reliable: 2
%--------------------------------------------------------------------------
warning('NOT TESTED!!!!!!!')

ImageField         = 'Im';
ImageFileNameField = 'ImageFileName';


DefV.TypeKeyVal         = {'dark','Dark','DARK'};
DefV.TypeKeyDic         = [];    % if empty use istype default.
DefV.FileNameStr        = [];    % e.g.., 'Bias' - if empty do not use file name
DefV.FitDark            = true;
DefV.RN                 = {'READNOI','READNOIS','RON'};  % if empty do not use   % [e-]
DefV.ExpTime            = {'AEXPTIME','EXPTIME'};  % exp time [s]
DefV.Nnoise             = 3;
DefV.StdFun             = @rstd;
DefV.GAIN               = {'GAIN'};
DefV.Template           = [];    % either SIM or a matrix
DefV.TemplateType       = 'ratio';
DefV.TemplateNoise      = 30;     % [ADU or ratio]
DefV.CombType           = @all;   % @all | @any
DefV.SelectMethod       = 'first';
if (numel(varargin)>0)
    InPar = set_varargin_keyval(DefV,'n','use',varargin{:});
else
    InPar = DefV;
end

if (~isempty(InPar.Template))
    if (isnumeric(InPar.Template))
        Template = SIM;
        Template.(ImageField) = InPar.Template;
    elseif (SIM.issim(InPar.Template))
        Template = InPar.Template;
    else
        error('Unknown Template format');
    end
end

% treat the input in case its an HEAD object
% Select bias images based on image TYPE keywords
IsDarkKey = istype(Sim,InPar.TypeKeyVal,InPar.TypeKeyDic);
IsDark    = IsDarkKey;

% treat the input in case its a SIM object
IsDarkFN      = false(numel(IsDark),1);
IsDarkStd     = false(numel(IsDark),1);
IsDarkTempStd = false(numel(IsDark),1);
if (SIM.issim(Sim))
    % select bias images based on file name
    if (~isempty(InPar.FileNameStr))
        % do not use file name
        IsDarkFN = ~Util.cell.isempty_cell(strfind({Sim.(ImageFileNameField)}.',InPar.FileNameStr));
        
        IsDark   = InPar.CombType([IsDark,IsDarkFN],2);
    end
    
    % fit the dark current as a function of ExpTime and look for outliers
    if (~isempty(InPar.FitDark))
        if (any(IsDarkKey))
            % get ExpTime
            ExpTime = cell2mat(getkey_fromlist(Sim(IsDarkKey),InPar.ExpTime,InPar.SelectMethod));
            % get readnoise
            RN = cell2mat(getkey_fromlist(Sim(IsDarkKey),InPar.RN,InPar.SelectMethod));
            % get GAIN
            Gain = cell2mat(getkey_fromlist(Sim(IsDarkKey),InPar.GAIN,InPar.SelectMethod));

        
            MedObs  = median(Sim(IsDarkKey));
            Par     = polyfit(ExpTime,MedObs,1);
            MedCalc = polyval(Par,ExpTime);
            Resid   = (MedObs-MedCalc);

            ResidErr= Resid.*Gain./sqrt(RN.^2 + Resid.*Gain);   % residuals normalized to errors
            IsDarkStd(IsDarkKey) = abs(ResidErr)<InPar.Nnoise;
        
            IsDark   = InPar.CombType([IsDark,IsDarkStd],2);
        end
    end
    
    
    
    % select images based on similarity to template
    if (~isempty(InPar.Template))
        switch lower(InPar.TemplateType)
            case 'diff'
                StdTempResid   = InPar.StdFun(Sim - Template);
            case 'ratio'
                StdTempResid   = InPar.StdFun(Sim./Template);
            otherwise
                error('Unknown TemplateType option');
        end
        IsDarkTempStd  = StdTempResid<InPar.TemplateNoise;
        
        IsDark   = InPar.CombType([IsDark,IsBiasTempStd],2); 
    end
        
end

Res.IsDarkKey     = IsDarkKey;
Res.IsDarkFN      = IsDarkFN;
Res.IsDarkStd     = IsDarkStd;
Res.IsDarkTempStd = IsDarkTempStd;






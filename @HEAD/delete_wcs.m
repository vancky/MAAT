function Head=delete_wcs(Head,KeyWCS,Templates)
%--------------------------------------------------------------------------
% delete_wcs function                                          class/@HEAD
% Description: Delete WCS header keywords from an HEAD object.
% Input  : - An HEAD object.
%          - Cell arry of header keywords to delete.
%            Default is:
%            {'RADECSYS','CTYPE1','CTYPE2','CUNIT1','CUNIT2',...
%             'CRPIX1','CRPIX2','CRVAL1','CRVAL2',...
%             'CD1_1','CD1_2','CD2_1','CD2_2',...
%             'CDELT1','CDELT2',...
%             'PC1_1','PC1_2','PC2_1','PC2_2',...
%             'LONPOLE','LATPOLE',...
%             'A_ORDER','B_ORDER','A_DMAX','B_DMAX',...
%             'AP_ORDER','BP_ORDER','AP_DMAX','BP_DMAX'}.
%            If empty use default.
%          - Cell array of regular expression templates to delete.
%            Default is
%            {'A_\d+_\d+','AP_\d+_\d+','B_\d+_\d+','BP_\d+_\d+','PV1_\d+','PV2_\d+'}.
% Output : - An HEAD object without the WCS keywords.
% License: GNU general public license version 3
% Tested : Matlab R2015b
%     By : Eran O. Ofek                    Apr 2016
%    URL : http://weizmann.ac.il/home/eofek/matlab/
% Example: Head=delete_wcs(Head)
% Reliable: 
%--------------------------------------------------------------------------
import Util.cell.*

HeaderField    = 'Header';

% delete main WCS keywords
Def.KeysWCS  = {'RADECSYS','CTYPE1','CTYPE2','CUNIT1','CUNIT2',...
            'CRPIX1','CRPIX2','CRVAL1','CRVAL2',...
            'CD1_1','CD1_2','CD2_1','CD2_2',...
            'CDELT1','CDELT2',...
            'PC1_1','PC1_2','PC2_1','PC2_2',...
            'LONPOLE','LATPOLE',...
            'A_ORDER','B_ORDER','A_DMAX','B_DMAX',...
            'AP_ORDER','BP_ORDER','AP_DMAX','BP_DMAX'};
Def.Templates = {'A_\d+_\d+','AP_\d+_\d+','B_\d+_\d+','BP_\d+_\d+','PV1_\d+','PV2_\d+'};

if (nargin==1),
    KeysWCS   = Def.KeysWCS;
    Templates = Def.Templates;
elseif (nargin==2),
    Templates = Def.Templates;
elseif (nargin==3),
    % do nothing
else
    error('Illegal number of input arguments');
end
    
if (isempty(KeysWCS)),
    KeysWCS = Def.KeysWCS;
end

    
Head = delete_key(Head,KeysWCS);
Col = 1;


% delete distortion keywords (SIP and PV)
Nh = numel(Head);
Nt = numel(Templates);
for Ih=1:1:Nh,
    
    % delete templates
    Flag = false(size(Head(Ih).(HeaderField),1),1);
    for It=1:1:Nt,
        Flag = Flag | ~isempty_cell(regexp(Head(Ih).(HeaderField)(:,Col),Templates{It}));
    end
    Head(Ih).(HeaderField) = Head(Ih).(HeaderField)(~Flag,:);   
    
    % delete WorldCooSys object
    Head(Ih).WCS = [];
end

%     % delete SIP distortion keywords
%     Flag = isempty_cell(regexp(Head(Ih).(HeaderField)(:,Col),'A_\d+_\d+')) & ...
%            isempty_cell(regexp(Head(Ih).(HeaderField)(:,Col),'AP_\d+_\d+')) & ...
%            isempty_cell(regexp(Head(Ih).(HeaderField)(:,Col),'B_\d+_\d+')) & ...
%            isempty_cell(regexp(Head(Ih).(HeaderField)(:,Col),'BP_\d+_\d+'));
%        
%     Head(Ih).(HeaderField) = Head(Ih).(HeaderField)(Flag,:);
%     
%     % delete TPV distortion keywords
%     Flag = isempty_cell(regexp(Head(Ih).(HeaderField)(:,Col),'PV1_\d+')) & ...
%            isempty_cell(regexp(Head(Ih).(HeaderField)(:,Col),'PV2_\d+'));
%        
%     Head(Ih).(HeaderField) = Head(Ih).(HeaderField)(Flag,:);
%     
%     % delete WorldCooSys object
%     Head(Ih).WCS = [];
% end
       

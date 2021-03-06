function [AstC]=cat_rotate(AstC,RotAng,RefCoo,varargin)
% Rotate coordinates in an AstCat object
% Package: @AstCat
% Description: Rotate X/Y coordinates in each catalog in an AstCat object.
% Input  : - An AstCat object.
%          - Vector or scalar or rotation angles [deg].
%          - Two column matrix of [X,Y] centers around to rotate the
%            coordinates.
%          * Arbitrary number of pairs of arguments: ...,keyword,value,...
%            where keyword are one of the followings:
%            'ColX' - Cell array of X axis column name. Use the first
%                     existing column. Default is {'XWIN_IMAGE','X'}.
%            'ColY' - Cell array of Y axis column name. Use the first
%                     existing column. Default is {'YWIN_IMAGE','Y'}.
% Output : - AStCat object with rotated coordinates.
% License: GNU general public license version 3
%     By : Eran O. Ofek                    Jan 2018
%    URL : http://weizmann.ac.il/home/eofek/matlab/
% Example: [CatRot]=cat_rotate(AstC,RotAng,RefCoo);
% Reliable: 
%--------------------------------------------------------------------------

CatField = AstCat.CatField;

if (nargin<3)
    RefCoo = [0 0];
    if (nargin<2)
        RotAng = 0;
    end
end

DefV.ColX                 = {'XWIN_IMAGE','X'};
DefV.ColY                 = {'YWIN_IMAGE','Y'};
InPar = InArg.populate_keyval(DefV,varargin,mfilename);

Ncat = numel(AstC);
Nrotang = numel(RotAng);
Nrefcoo = size(RefCoo,1);

for Icat=1:1:Ncat

    [~,X_ColInd,X_UseInd]=select_exist_colnames(AstC(Icat),InPar.ColX);
    [~,Y_ColInd,Y_UseInd]=select_exist_colnames(AstC(Icat),InPar.ColY);
    X_ColInd = X_ColInd(find(~isnan(X_ColInd),1,'first'));
    Y_ColInd = Y_ColInd(find(~isnan(Y_ColInd),1,'first'));

    X = AstC(Icat).(CatField)(:,X_ColInd);
    Y = AstC(Icat).(CatField)(:,Y_ColInd);
    
    RefX  = RefCoo(min(Nrefcoo,Icat),1);
    RefY  = RefCoo(min(Nrefcoo,Icat),2);
    Rot   = RotAng(min(Nrefcoo,Icat));
    
    AstC(Icat).(CatField)(:,X_ColInd) = (X - RefX).*cosd(Rot) - (Y - RefY).*sind(Rot);
    AstC(Icat).(CatField)(:,Y_ColInd) = (X - RefX).*sind(Rot) + (Y - RefY).*cosd(Rot);
end
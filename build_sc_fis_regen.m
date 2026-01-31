function fis = build_sc_fis_regen(Pbase, Pmax)
% =========================================================
% Supercapacitor EMS Fuzzy Controller (Regen included)
% Input1 : SOC_E  [0, 1]
% Input2 : Pnorm  [-Pn_max, +Pn_max], Pnorm = P_real / Pbase
% Output : Ksc    [-1, 1]
%   Ksc > 0 => Supercap DISCHARGE  (P_sc_cmd > 0)
%   Ksc < 0 => Supercap CHARGE     (P_sc_cmd < 0)
%
% Recommend:
%   P_sc_cmd = abs(Pnorm) * Ksc * Pbase   (W)
%           = abs(P_real) * Ksc           (W)
% =========================================================

if nargin < 1, Pbase = 1e4; end
if nargin < 2, Pmax  = 3e4; end

Pn_max = Pmax / Pbase;   % normalized max power, e.g. 3 for 30kW/10kW

fis = mamfis( ...
    'Name','sc_ems_regen', ...
    'AndMethod','min', ...
    'OrMethod','max', ...
    'ImplicationMethod','min', ...
    'AggregationMethod','max', ...
    'DefuzzificationMethod','centroid');

%% ---------------- Input 1: SOC_E [0,1] ----------------
fis = addInput(fis,[0 1],'Name','SOC_E');

% 类似你图5的形状：Low(左边平滑下降), Mid(三角), High(右边平滑上升)
fis = addMF(fis,'SOC_E','zmf',[0.35 0.60],'Name','L');                 % Low
fis = addMF(fis,'SOC_E','trimf',[0.35 0.60 0.85],'Name','M');          % Mid
fis = addMF(fis,'SOC_E','smf',[0.60 0.85],'Name','G');                 % High

%% ---------------- Input 2: Pnorm [-Pn_max, +Pn_max] ----------------
fis = addInput(fis,[-Pn_max Pn_max],'Name','Pnorm');

% 5个：NB(强再生), NM(弱再生), ZE(零), PM(弱驱动), PB(强驱动)
a = Pn_max;
fis = addMF(fis,'Pnorm','trapmf',[-a -a -0.8*a -0.4*a],'Name','NB');
fis = addMF(fis,'Pnorm','trimf',[-0.8*a -0.4*a 0],'Name','NM');
fis = addMF(fis,'Pnorm','trimf',[-0.2*a 0 0.2*a],'Name','ZE');
fis = addMF(fis,'Pnorm','trimf',[0 0.4*a 0.8*a],'Name','PM');
fis = addMF(fis,'Pnorm','trapmf',[0.4*a 0.8*a a a],'Name','PB');

%% ---------------- Output: Ksc [-1,1] ----------------
fis = addOutput(fis,[-1 1],'Name','Ksc');

fis = addMF(fis,'Ksc','trapmf',[-1 -1 -0.8 -0.4],'Name','CHG_H');
fis = addMF(fis,'Ksc','trimf',[-0.8 -0.4 0],'Name','CHG_L');
fis = addMF(fis,'Ksc','trimf',[-0.03 0 0.03],'Name','ZERO');
fis = addMF(fis,'Ksc','trimf',[0 0.4 0.8],'Name','DIS_L');
fis = addMF(fis,'Ksc','trapmf',[0.4 0.8 1 1],'Name','DIS_H');

%% ---------------- Rule base ----------------
% Index:
% SOC_E: 1=L,2=M,3=G
% Pnorm: 1=NB,2=NM,3=ZE,4=PM,5=PB
% Ksc  : 1=CHG_H,2=CHG_L,3=ZERO,4=DIS_L,5=DIS_H

rules = [
% SOC  Pnorm   Ksc     w  AND
% ---------- SOC LOW ----------
  1     1      1       1   1   % 强再生 -> 强充电
  1     2      1       1   1   % 弱再生 -> 充电
  1     3      2       1   1   % 零功率 -> 轻充（维持 SOC）
  1     4      2       1   1   % 驱动 -> 允许充电（关键）
  1     5      2       1   1   % 大功率 -> 轻充，避免放电

% ---------- SOC MID ----------
  2     1      2       1   1   % 再生 -> 适度充电
  2     2      2       1   1
  2     3      3       1   1   % 平衡
  2     4      4       1   1   % 驱动 -> 放电
  2     5      5       1   1   % 大功率 -> 强放

% ---------- SOC HIGH ----------
  3     1      3       1   1   % 再生 -> 不再充
  3     2      3       1   1
  3     3      3       1   1
  3     4      5       1   1   % 驱动 -> 强放
  3     5      5       1   1
];


fis = addRule(fis,rules);

% save
writeFIS(fis,'sc_ems_regen.fis');
disp('✔ Saved: sc_ems_regen.fis');
end

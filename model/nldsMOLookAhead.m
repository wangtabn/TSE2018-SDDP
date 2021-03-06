function [cntr, obj] = nldsMOLookAhead(scenario, var, GeneratorConv,GeneratorPS,GeneratorWS,Loads,Bus,Lines, UC,H)

%the horizon is from 4 to 93
LookAhead = 1;   % look ahead horizon
t = scenario.getTime() ;
nBus = size(Bus, 1);
BasePower = 100;
nLines = size(Lines, 1);
load('PSProfile.mat')   %optimal profile of pumped storage when error is 0
load 'myPath96.mat';
%global common_cstr
%%% wind and solar
ProductionWS = csvread('RenewableData.csv', 4, 1, [4,1,93,1]); % use RT_production as forecast

%%% loads
totalLoad = csvread('Data.csv', 4, 0, [4,0,93,0]);
FixedSupply = csvread('Data.csv', 4, 1, [4,1,93,1]);    % fixed conventional generator production
totalLoad = totalLoad - FixedSupply + ProductionWS;      % wind and solar is included in fixed supply, so here we need to

%%% conventional Generators
FuelCost = GeneratorConv.FuelCost;
MinRunCapacity = GeneratorConv.MinRunCapacity;
MaxRunCapacity = GeneratorConv.MaxRunCapacity;
MaxTransitionLevel = GeneratorConv.MaxTransitionLevel;
RampUp = GeneratorConv.RampUp;
RampDown = GeneratorConv.RampDown;
hr1 = GeneratorConv.hr1;
hr2 = GeneratorConv.hr2;
hr3 = GeneratorConv.hr3;
f1 = GeneratorConv.f1;
f2 = GeneratorConv.f2;
f3 = GeneratorConv.f3;



%%% pumped storage
PSCapacity = GeneratorPS.Capacity;

%%% decision variables

s = var.s ;             % storage of pumped storage
p_pump = var.p_pump;    % power pumped to pumped storage
p_prod = var.p_prod;    % power produced by pumped storage
p = var.p;              % Production of gas generators
c = var.c;              % cost of gas generators at the coresponding production level
ls = var.ls ;           % load shedding

redispatchC = var.redispatchC;  % redispatch cost

psh = var.psh;          % production shedding
flow = var.flow;        %
angle = var.angle;

% variables for look ahead one step
s1 = var.s1 ;             % storage of pumped storage
p_pump1 = var.p_pump1;    % power pumped to pumped storage
p_prod1 = var.p_prod1;    % power produced by pumped storage
p1 = var.p1;              % Production of gas generators
c1 = var.c1;              % cost of gas generators at the coresponding production level
ls1 = var.ls1 ;           % load shedding

redispatchC1 = var.redispatchC1;  % redispatch cost

psh1 = var.psh1;          % production shedding
flow1 = var.flow1;        %
angle1 = var.angle1;




e=var.e;                % percentage WP/WF
ruc = var.ruc;
rdc = var.rdc;

% when in the duration, minimize the cost of current stage and the cost of one stage look ahead
if t <= H-LookAhead
    obj = 0.25*redispatchC(t)+0.25*sum(c(:,t))  + 0.25*redispatchC1(t)*1+0.25*sum(c1(:,t))*1;
else
    obj = 0.25*redispatchC(t)+0.25*sum(c(:,t)) ;
end


productionCost = [
    c(:,t) >= FuelCost.*(f1.*UC(:,t) + hr1.*p(:,t));
    c(:,t) >= FuelCost.*(f2.*UC(:,t) + hr2.*p(:,t));
    c(:,t) >= FuelCost.*(f3.*UC(:,t) + hr3.*p(:,t));
    
    redispatchC(t) >= 100*sum(ls(:,t));
    redispatchC(t) >= 200*sum(ls(:,t)) - 1e5;
    redispatchC(t) >= 300*sum(ls(:,t)) - 3e5;
    redispatchC(t) >= 400*sum(ls(:,t)) - 6e5;
    redispatchC(t) >= 500*sum(ls(:,t)) - 10e5;
    
    c1(:,t) >= FuelCost.*(f1.*UC(:,t) + hr1.*p1(:,t));
    c1(:,t) >= FuelCost.*(f2.*UC(:,t) + hr2.*p1(:,t));
    c1(:,t) >= FuelCost.*(f3.*UC(:,t) + hr3.*p1(:,t));
    
    redispatchC1(t) >= 100*sum(ls1(:,t));
    redispatchC1(t) >= 200*sum(ls1(:,t)) - 1e5;
    redispatchC1(t) >= 300*sum(ls1(:,t)) - 3e5;
    redispatchC1(t) >= 400*sum(ls1(:,t)) - 6e5;
    redispatchC1(t) >= 500*sum(ls1(:,t)) - 10e5;
    
    ];

bounds = [
    %     flow(:,t) <= Lines.FlowLimitForw;
    %     flow(:,t) >= - Lines.FlowLimitBack;
    
    
    
    p_pump(:,t) == p_pump0(:,t);
    p_prod(:,t) == p_prod0(:,t);
    
    
    p(:,t) + ruc(:,t)<=MaxRunCapacity.*UC(:,t);
    p(:,t) - rdc(:,t)>=MinRunCapacity.*UC(:,t);
    
    p1(:,t) <=MaxRunCapacity.*UC(:,t);
    p1(:,t) >=MinRunCapacity.*UC(:,t);
    
    
    ls(:,t) >= 0;
    psh(:,t) >= 0;
    
    ls1(:,t) >= 0;
    psh1(:,t) >= 0;
    
    ruc(:,t) >= 0;	% ramp up capacity
    rdc(:,t) >= 0;	% ramp down capacity
    
    ruc(:,t) <= RampUp*15;
    rdc(:,t) <= RampDown*15;    
    ];





if t==1
    UC0 = UC(:,1); %on-off state at 0 is the same as at 1
    errorDynamics = e(t) == scenario.data ;
    pumpedStorage = [
        s(:,t) == 38.7*PSCapacity/sum(PSCapacity) + (p_pump(:,t)*0.765 - p_prod(:,t))*0.25;
        s1(:,t) == s(:,t) + (p_pump1(:,t)*0.765 - p_prod1(:,t))*0.25;
        ]; % initial storage in MWh
    
    rampRate = [
        p(:,t) - 0 <= RampUp.*UC0*1500; % the unit of RampUp is MW/m
        0 - p(:,t) <= RampDown.*UC(:,1)*1500;
        
        p1(:,t) - p(:,t) <= RampUp*15*LookAhead; % the unit of RampUp is MW/m
        p(:,t) - p1(:,t) <= RampDown*15*LookAhead;
        ];
    
else
    errorDynamics = e(t) ==  (e(t-1)*0.9994 + 0.00057)*scenario.data;
    pumpedStorage = [
        s(:,t) == s(:,t-1) + (p_pump(:,t)*0.765 - p_prod(:,t))*0.25;
        s1(:,t) == s(:,t) + (p_pump1(:,t)*0.765 - p_prod1(:,t))*0.25;
        ]; % the unit of s is MWh
    
    rampRate = [
        p(:,t) - p(:,t-1) <= RampUp*15; % the unit of RampUp is MW/m
        p(:,t-1) - p(:,t) <= RampDown*15;
        
        p1(:,t) - p(:,t) <= RampUp*15*LookAhead; % the unit of RampUp is MW/m
        p(:,t) - p1(:,t) <= RampDown*15*LookAhead;
        
        ];
end



% angle formulation
% strcmp is used to get logic variable,  to refer to the correct bus
flowCalc = [];
% for line = 1:nLines
%     flowCalc = [flowCalc;
%         flow(line, t) == BasePower/Lines.Reactance(line)*(angle(strcmp(Lines.FromBus(line),Bus.Name), t)-angle(strcmp(Lines.ToBus(line),Bus.Name), t));
%         ];
% end


%%% load and production shedding constraints
% strcmp is used to determime whether this unit/load is on the bus
% loadshedding/productionshedding at this bus can not exceed load/production at this bus
Shedding = [];
% for bus = 1:nBus
%     Shedding = [Shedding;
%         ls(bus,t) <= totalLoad(t)*sum(strcmp(Loads.BusLoad,Bus.Name(bus)).*Loads.ParticipationFactor)...
%         + sum(PSCapacity.*strcmp(GeneratorPS.Bus,Bus.Name(bus)));
%
%         psh(bus,t) <= sum(p(:,t).*strcmp(GeneratorConv.BusGenerator,Bus.Name(bus)))...
%         + sum(strcmp(GeneratorWS.BusGenerators,Bus.Name(bus)).*GeneratorWS.ReferenceValue.*GeneratorWS.ParticipationFactor.*GeneratorWS.(strcat('Period', num2str(t+3))))...
%         /sum(GeneratorWS.ReferenceValue.*GeneratorWS.ParticipationFactor.*GeneratorWS.(strcat('Period', num2str(t+3))))*ProductionWS(t)*e(t)...
%         + sum(strcmp(GeneratorPS.Bus,Bus.Name(bus)).*PSCapacity);
%         ];% can also use sum(Loads.ParticipationFactor(strcmp(Loads.BusLoad,Bus.Name(b))))
% end


% demand supply balance at each bus
% strcmp is used to determime whether this unit/load is on the bus
% load + pump + flowFromBus = productionConv + prodPS + prodWS
% (=ParticipationFactor*profile ) + loadshedding + flowToBus
satisifyDemand = [];
% for bus = 1:nBus
%     satisifyDemand = [satisifyDemand;
%         totalLoad(t)*sum(strcmp(Loads.BusLoad,Bus.Name(bus)).*Loads.ParticipationFactor) ...
%         + sum(p_pump(:,t).*strcmp(GeneratorPS.Bus,Bus.Name(bus)))...
%         + sum(flow(:,t).*strcmp(Lines.FromBus,Bus.Name(bus))) ...
%         + psh(bus,t)...
%         == sum(p(:,t).*strcmp(GeneratorConv.BusGenerator,Bus.Name(bus)))...
%         + sum(p_prod(:,t).*strcmp(GeneratorPS.Bus,Bus.Name(bus)))...
%         + sum(strcmp(GeneratorWS.BusGenerators,Bus.Name(bus)).*GeneratorWS.ReferenceValue.*GeneratorWS.ParticipationFactor.*GeneratorWS.(strcat('Period', num2str(t+3))))...
%         /sum(GeneratorWS.ReferenceValue.*GeneratorWS.ParticipationFactor.*GeneratorWS.(strcat('Period', num2str(t+3))))*ProductionWS(t)*e(t)...
%         + sum(flow(:,t).*strcmp(Lines.ToBus,Bus.Name(bus))) ...
%         + ls(bus,t);];
% end

% assume the first one as HubBus
% angleZero = angle(1, t) == 0;
angleZero =[];

satisifyDemand =sum(p(:,t)) + sum(p_prod(:,t)) + ProductionWS(t)*e(t) + sum(ls(:,t)) == totalLoad(t) + sum(p_pump(:,t)) + sum(psh(:,t));

if t <= H-LookAhead
    bounds = [
        bounds;
%         sum(ruc(:,t)) >= ProductionWS(t)*e(t) - (e(t)*0.9994 + 0.00057)*0.9855*ProductionWS(t+1)
%         sum(rdc(:,t)) >= (e(t)*0.9994 + 0.00057)*1.0047*ProductionWS(t+1) - ProductionWS(t)*e(t)
        
        
        p_pump1(:,t) == p_pump0(:,t+LookAhead);
        p_prod1(:,t) == p_prod0(:,t+LookAhead);
        ];
    
    satisifyDemand = [
        satisifyDemand;
        sum(p1(:,t)) + sum(p_prod1(:,t)) + ProductionWS(t+LookAhead)*(e(t)*0.9994 + 0.00057) + sum(ls1(:,t)) == totalLoad(t+LookAhead) + sum(p_pump1(:,t)) + sum(psh1(:,t));
        %*norminv(myPath(1,t+LookAhead)/10-0.05,1,0.0376)
        ];
end


cntr= [satisifyDemand; rampRate; bounds; errorDynamics; productionCost; Shedding; flowCalc; angleZero; pumpedStorage];


end


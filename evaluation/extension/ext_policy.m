function [pol, W] = ext_policy(agentFile)
%EXT_POLICY  Deterministische Policy eines PPO-Agenten als schnelle Funktion (X0.2).
%   pol = ext_policy(file)     pol(obs) liefert die Rohaktion 7x1 (Mittelwert des Gauss-Actors)
%   [pol, W] = ext_policy(file)
%
%   Liest die Gewichte aus dem dlnetwork des Actors (Feature Input 29, fc_1, ReLU, fc_body, ReLU, fc_mean, tanh)
%   und rechnet den Mittelwert direkt. Das entspricht getAction mit UseExplorationPolicy = false, ist aber
%   etwa tausendmal schneller. ext_x0_validate_kinsim prueft die Gleichheit mit getAction.
%   Wie getAction (und der RL-Agent-Block) wird die Beobachtung vorher elementweise auf LowerLimit und
%   UpperLimit der ObservationInfo begrenzt (gefunden 10.11.2026, ohne Begrenzung bis 2 Abweichung).
%   Die Grenzen stehen in der Reihenfolge des Deploy-Skripts V2.1, nicht in der des Trainings (A72).
%   W.lo, W.hi sind die Grenzen.

S = load(agentFile, 'agent');
net = getModel(getActor(S.agent));
assert(isa(net, 'dlnetwork'), 'ext_policy:net', 'Actor ist kein dlnetwork');
L = net.Learnables;
get = @(layer, par) double(extractdata(L.Value{strcmp(L.Layer, layer) & strcmp(L.Parameter, par)}));
names = {net.Layers.Name};
need = {'fc_1', 'relu_body', 'fc_body', 'body_output', 'fc_mean', 'tanh'};
assert(all(ismember(need, names)), 'ext_policy:layers', 'Unerwarteter Aufbau des Actors: %s', strjoin(names, ', '));
W = struct('W1', get('fc_1', 'Weights'), 'b1', get('fc_1', 'Bias'), ...
           'W2', get('fc_body', 'Weights'), 'b2', get('fc_body', 'Bias'), ...
           'W3', get('fc_mean', 'Weights'), 'b3', get('fc_mean', 'Bias'));
oi = getObservationInfo(S.agent);
W.lo = double(oi.LowerLimit(:));
W.hi = double(oi.UpperLimit(:));
pol = @(o) tanh(W.W3 * max(W.W2 * max(W.W1 * min(max(o, W.lo), W.hi) + W.b1, 0) + W.b2, 0) + W.b3);
end

--!strict
--[[
    Model3DSync.luau
    Ubicación: ServerScriptService.Modules.Core.Model3DSync
    Propósito:
    Escucha los deltas del motor lógico (SnapshotManager.OnDelta) y sincroniza
    la posición física de los modelos 3D en workspace.AnimatronicModels hacia
    los puntos de movimiento en workspace.MapBlockoutV2.MovementPoints.
]]

local Model3DSync = {}

function Model3DSync.conectar(snapshotManager: any): RBXScriptConnection?
    if not snapshotManager or not snapshotManager.OnDelta then
        return nil
    end

    return snapshotManager.OnDelta.Event:Connect(function(lineaId: string, delta: any)
        if not delta or delta.tipo ~= "MOVER_ANIMATRONICO" then
            return
        end

        local mapa3D = workspace:FindFirstChild("MapBlockoutV2")
        local modelos3D = workspace:FindFirstChild("AnimatronicModels")
        if not mapa3D or not modelos3D then
            return
        end

        local movementPoints = mapa3D:FindFirstChild("MovementPoints")
        if not movementPoints then
            return
        end

        local punto = movementPoints:FindFirstChild(delta.valorNuevo)
        local modelo = modelos3D:FindFirstChild(delta.entidadId)
        if punto and punto:IsA("BasePart") and modelo and modelo:IsA("Model") then
            modelo:SetAttribute("CurrentNode", delta.valorNuevo)
            modelo:SetAttribute("TimelineId", lineaId)
            modelo:PivotTo(CFrame.new(punto.Position + Vector3.new(0, 0.6, 0)))
        end
    end)
end

return Model3DSync


AddCSLuaFile()

SWEP.PrintName = "#GMOD_Fists"
--SWEP.Author = "Kilburn, robotboy655, MaxOfS2D & Tenrys"
--SWEP.Purpose = "Well we sure as hell didn't use guns! We would just wrestle Hunters to the ground with our bare hands! I used to kill ten, twenty a day, just using my fists."

SWEP.BounceWeaponIcon = false
SWEP.DrawWeaponInfoBox = false

SWEP.Slot = 0
SWEP.SlotPos = 4

SWEP.Spawnable = true

SWEP.ViewModel = Model( "models/weapons/c_arms.mdl" )
SWEP.WorldModel = ""
SWEP.ViewModelFOV = 54
SWEP.UseHands = true

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = true
SWEP.Secondary.Ammo = "none"

SWEP.IronSightsPos = Vector(0, -3.594, -0.801)
SWEP.IronSightsAng = Vector(27.564, 0, 0)

SWEP.v_bonemods = {}

SWEP.ViewModelBoneMods = {
	["ValveBiped.Bip01_L_UpperArm"] = { scale = Vector(1, 1, 1), pos = Vector(-3.487, -0.242, 0), angle = Angle(0, 0, 0) },
	["ValveBiped.Bip01_R_UpperArm"] = { scale = Vector(1, 1, 1), pos = Vector(-3.152, 0, 0), angle = Angle(0, 0, 0) }
}

if CLIENT then
	killicon.Add( "weapon_fists", "HUD/weapons/weapon_fists/killicon", Color( 255, 255, 255, 255 ) )
	SWEP.WepSelectIcon = surface.GetTextureID("HUD/weapons/weapon_fists/selecticon")
end

if SERVER then
	resource.AddFile("materials/HUD/weapons/weapon_fists/selecticon.vmt")
	resource.AddFile("materials/HUD/weapons/weapon_fists/killicon.vmt")
end

SWEP.DrawAmmo = false

SWEP.HitDistance = 48

local SwingSound = Sound( "WeaponFrag.Throw" )
local HitSound = Sound( "Flesh.ImpactHard" )

function SWEP:Initialize()

	self:SetHoldType( "fist" )
	self:SetLower(false)
	self:SetBlock(false)

end

function SWEP:SetupDataTables()

	self:NetworkVar( "Float", 0, "NextMeleeAttack" )
	self:NetworkVar( "Float", 1, "NextIdle" )
	self:NetworkVar( "Float", 2, "NextBlock" )
	self:NetworkVar( "Float", 3, "NextLower" )
	self:NetworkVar( "Int", 2, "Combo" )
	self:NetworkVar( "Bool", 1, "Lower" )
	self:NetworkVar( "Bool", 2, "Block" )

end

function SWEP:UpdateNextIdle()

	local vm = self.Owner:GetViewModel()
	self:SetNextIdle( CurTime() + vm:SequenceDuration() / vm:GetPlaybackRate() )

end

function SWEP:DoDrawCrosshair()
	if self:GetLower() || self:GetBlock() then
		return true
	end
end

function SWEP:PrimaryAttack()

	if self:GetLower() || self:GetBlock() then return end

	self.Owner:SetAnimation( PLAYER_ATTACK1 )
	local anim = "fists_left"
	if ( self:GetCombo() >= 2 ) then
		anim = "fists_uppercut"
	else
		local r = util.SharedRandom( self:GetClass(), 0, 1, 0 )
		if ( r > 0.5 ) then anim = "fists_right" end
	end

	local vm = self.Owner:GetViewModel()
	vm:SendViewModelMatchingSequence( vm:LookupSequence( anim ) )

	self:EmitSound( SwingSound )

	self:UpdateNextIdle()
	self:SetNextMeleeAttack( CurTime() + 0.2 )

	self:SetNextPrimaryFire( CurTime() + 0.9 )
	--self:SetNextSecondaryFire( CurTime() + 0.9 )

end

local phys_pushscale = GetConVar( "phys_pushscale" )

function SWEP:DealDamage()

	local anim = self:GetSequenceName(self.Owner:GetViewModel():GetSequence())

	self.Owner:LagCompensation( true )

	local tr = util.TraceLine( {
		start = self.Owner:GetShootPos(),
		endpos = self.Owner:GetShootPos() + self.Owner:GetAimVector() * self.HitDistance,
		filter = self.Owner,
		mask = MASK_SHOT_HULL
	} )

	if ( !IsValid( tr.Entity ) ) then
		tr = util.TraceHull( {
			start = self.Owner:GetShootPos(),
			endpos = self.Owner:GetShootPos() + self.Owner:GetAimVector() * self.HitDistance,
			filter = self.Owner,
			mins = Vector( -10, -10, -8 ),
			maxs = Vector( 10, 10, 8 ),
			mask = MASK_SHOT_HULL
		} )
	end

	-- We need the second part for single player because SWEP:Think is ran shared in SP
	if ( tr.Hit && !( game.SinglePlayer() && CLIENT ) ) then
		self:EmitSound( HitSound )
	end

	local hit = false
	local scale = phys_pushscale:GetFloat()

	if ( SERVER && IsValid( tr.Entity ) && ( tr.Entity:IsNPC() || tr.Entity:IsPlayer() || tr.Entity:Health() > 0 ) ) then
		local dmginfo = DamageInfo()

		local attacker = self.Owner
		if ( !IsValid( attacker ) ) then attacker = self end
		dmginfo:SetAttacker( attacker )

		dmginfo:SetInflictor( self )
		dmginfo:SetDamage( math.random( 8, 12 ) )

		if ( anim == "fists_left" ) then
			dmginfo:SetDamageForce( self.Owner:GetRight() * 4912 * scale + self.Owner:GetForward() * 9998 * scale ) -- Yes we need those specific numbers
		elseif ( anim == "fists_right" ) then
			dmginfo:SetDamageForce( self.Owner:GetRight() * -4912 * scale + self.Owner:GetForward() * 9989 * scale )
		elseif ( anim == "fists_uppercut" ) then
			dmginfo:SetDamageForce( self.Owner:GetUp() * 5158 * scale + self.Owner:GetForward() * 10012 * scale )
			dmginfo:SetDamage( math.random( 12, 24 ) )
		end

		SuppressHostEvents( NULL ) -- Let the breakable gibs spawn in multiplayer on client
		tr.Entity:TakeDamageInfo( dmginfo )
		SuppressHostEvents( self.Owner )

		hit = true

	end

	if ( IsValid( tr.Entity ) ) then
		local phys = tr.Entity:GetPhysicsObject()
		if ( IsValid( phys ) ) then
			phys:ApplyForceOffset( self.Owner:GetAimVector() * 80 * phys:GetMass() * scale, tr.HitPos )
		end
	end

	if ( SERVER ) then
		if ( hit && anim != "fists_uppercut" ) then
			self:SetCombo( self:GetCombo() + 1 )
		else
			self:SetCombo( 0 )
		end
	end

	self.Owner:LagCompensation( false )

end

local Mul = 0
local MulA = 0

function SWEP:GetViewModelPosition(EyePos, EyeAng)
	local block = self:GetBlock()
	local lower = self:GetLower()
	Mul = math.Approach(Mul, block && 1 || lower && -1 || 0, FrameTime()*6)

	local MulEase = Mul

	local Offset = self.IronSightsPos

	if (self.IronSightsAng) then
        EyeAng = EyeAng * 1
        
		EyeAng:RotateAroundAxis(EyeAng:Right(), 	self.IronSightsAng.x * MulEase)
		EyeAng:RotateAroundAxis(EyeAng:Up(), 		self.IronSightsAng.y * MulEase)
		EyeAng:RotateAroundAxis(EyeAng:Forward(),   self.IronSightsAng.z * MulEase)
	end

	local Right 	= EyeAng:Right()
	local Up 		= EyeAng:Up()
	local Forward 	= EyeAng:Forward()

	EyePos = EyePos + Offset.x * Right * MulEase
	EyePos = EyePos + Offset.y * Forward * MulEase
	EyePos = EyePos + Offset.z * Up * MulEase
	
	return EyePos, EyeAng
end

function SWEP:OnDrop()

	self.Owner.FISTRSDMG = nil
	self:Remove() -- You can't drop fists

end

local fistdeployspeed = CreateConVar("fists_deployspeed", "3", FCVAR_ARCHIVE)

function SWEP:Deploy()

	local lower = self:GetLower()
	self.Owner.FISTRSDMG = nil
	--if !lower then 
		self:SetNextLower(CurTime() + 0.25)
		self:SetNextBlock(CurTime() + 0.25)
	--end
	local speed = fistdeployspeed:GetFloat()
	local vm = self.Owner:GetViewModel()
	if lower then
		vm:SendViewModelMatchingSequence( vm:LookupSequence( "fists_holster" ) )
		self:SetHoldType( "normal" )
		return
	end
	vm:SendViewModelMatchingSequence( vm:LookupSequence( "fists_draw" ) )
	--vm:SetPlaybackRate( speed )

	self:SetNextPrimaryFire( CurTime() + vm:SequenceDuration() / speed )
	--self:SetNextSecondaryFire( CurTime() + vm:SequenceDuration() / speed )
	self:UpdateNextIdle()
	self:SetHoldType( "fist" )
	if ( SERVER ) then
		self:SetCombo( 0 )
	end

	return true

end

function SWEP:Holster()
	self.Owner.FISTRSDMG = nil
	self:SetBlock(false)
	self:SetNextMeleeAttack( 0 )
	if CLIENT and IsValid(self.Owner) then
		local vm = self.Owner:GetViewModel()
		if IsValid(vm) then
			self:ResetBonePositions(vm)
		end
	end
	return true
end

function SWEP:Lower()
	--local vm = self.Owner:GetViewModel()
	--vm:SendViewModelMatchingSequence( vm:LookupSequence( "fists_holster" ) )

	self:SetHoldType( "normal" )
	self:SetNextBlock(CurTime() + 0.25)
	self:SetNextMeleeAttack( 0 )
	--self:SetLower(true)
	self:SetBlock(false)
	return true
end

hook.Add( "EntityTakeDamage", "EntityDamageExample", function( target, dmginfo )
	local dmgt = dmginfo:GetDamageType()
	if ( target:IsPlayer() and (dmgt == DMG_CRUSH || dmgt == DMG_SLASH || dmgt == DMG_GENERIC) and target.FISTRSDMG ) then
		dmginfo:ScaleDamage( math.Rand(0.5, 0.7) )
	end
end )


hook.Add( "PostPlayerDeath", "EntityDamageExample", function( ply )
	ply.FISTRSDMG = nil
end )

function SWEP:Block()
	self:SetHoldType( "camera" )
	self:SetNextMeleeAttack( 0 )
	self:SetLower(false)
	self.Owner.FISTRSDMG = true
	self:SetNextIdle( CurTime() )
	--self:SetBlock(true)
	return true
end

function SWEP:UnBlock()
	--hook.Remove("ScalePlayerDamage", self.Owner:UserID() .. "FISTRESIST")
	self:SetHoldType( "fist" )
	self.Owner.FISTRSDMG = nil
	--self:SetNextMeleeAttack( CurTime() + 0.1 )
	--self:SetBlock(false)
	return true
end

function SWEP:Reload()
	if self:GetNextLower() > CurTime() then return end
	if self:GetBlock() then self:SetNextBlock(CurTime() + 0.25) self:SetBlock(false) self:UnBlock() return end
	if !self.Owner:KeyPressed(IN_RELOAD) then return end
	self:SetNextLower(CurTime() + 0.25)
	local lower = self:GetLower()
	self:SetLower(!lower)
	if !lower then self:Lower() else self:Deploy() end
end

local blocktoggle = CreateConVar("fists_toggle", "0", FCVAR_ARCHIVE)

function SWEP:SecondaryAttack()
	if self:GetNextBlock() > CurTime() then return end
	if !self.Owner:KeyPressed(IN_ATTACK2) then return end
	if self:GetLower() then return end
	self:SetNextBlock(CurTime() + 0.25)
	local block = self:GetBlock()
	self:SetBlock(!block)
	if !block then self:Block() else self:UnBlock() end
end

function SWEP:Think()
	local lower = self:GetLower()
	local block = self:GetBlock()

	local vm = self.Owner:GetViewModel()
	local curtime = CurTime()
	local idletime = self:GetNextIdle()

	if ( idletime > 0 && CurTime() > idletime ) then

		local r = util.SharedRandom( self:GetClass(), 0, 1, 0 )
		local bl = r > 0.5
		local num = 1
		if bl then num = 2 end
		vm:SendViewModelMatchingSequence( vm:LookupSequence( "fists_idle_0" .. num) )

		self:UpdateNextIdle()

	end

	if block && self:GetNextBlock() < CurTime() && !self.Owner:KeyDown(IN_ATTACK2) && !blocktoggle:GetBool() then
		self:SetNextBlock(CurTime() + 0.25) self:SetBlock(false) self:UnBlock()
	end

	if !lower || !block then
		local meleetime = self:GetNextMeleeAttack()

		if ( meleetime > 0 && CurTime() > meleetime ) then

			self:DealDamage()

			self:SetNextMeleeAttack( 0 )

		end

		if ( SERVER && CurTime() > self:GetNextPrimaryFire() + 0.1 ) then

			self:SetCombo( 0 )

		end
	end
end

local allbones
local hasGarryFixedBoneScalingYet = false
 
function SWEP:ResetBonePositions(vm)
	
	if (!vm:GetBoneCount()) then return end
	
	for i=0, vm:GetBoneCount() do
		vm:ManipulateBoneScale( i, Vector(1, 1, 1) )
		vm:ManipulateBoneAngles( i, Angle(0, 0, 0) )
		vm:ManipulateBonePosition( i, Vector(0, 0, 0) )
	end
	
end

function SWEP:UpdateBonePositions(vm)
	if self.ViewModelBoneMods then
		
		if (!vm:GetBoneCount()) then return end
		
		local loopthrough = self.ViewModelBoneMods
		if (!hasGarryFixedBoneScalingYet) then
			allbones = {}
			for i=0, vm:GetBoneCount() do
				local bonename = vm:GetBoneName(i)
				if (self.ViewModelBoneMods[bonename]) then 
					allbones[bonename] = self.ViewModelBoneMods[bonename]
				else
					allbones[bonename] = { 
						scale = Vector(1,1,1),
						pos = Vector(0,0,0),
						angle = Angle(0,0,0)
					}
				end
			end
			
			loopthrough = allbones
		end
		
		for k, v in pairs( loopthrough ) do
			local bone = vm:LookupBone(k)
			if (!bone) then continue end
			
			--local s = Vector(v.scale.x,v.scale.y,v.scale.z) --* Mul
			local p = Vector(v.pos.x,v.pos.y,v.pos.z) * Mul
			local ms = Vector(1,1,1)
			if (!hasGarryFixedBoneScalingYet) then
				local cur = vm:GetBoneParent(bone)
				while(cur >= 0) do
					local pscale = loopthrough[vm:GetBoneName(cur)].scale
					ms = ms * pscale
					cur = vm:GetBoneParent(cur)
				end
			end
			
			--s = s * ms
			
			--if vm:GetManipulateBoneScale(bone) != s then
			--	vm:ManipulateBoneScale( bone, s )
			--end
			if vm:GetManipulateBoneAngles(bone) != v.angle then
				vm:ManipulateBoneAngles( bone, v.angle )
			end
			if vm:GetManipulateBonePosition(bone) != p then
				vm:ManipulateBonePosition( bone, p )
			end
		end
	else
		self:ResetBonePositions(vm)
	end
end
 
function SWEP:ResetBonePositions(vm)
	
	if (!vm:GetBoneCount()) then return end
	
	for i=0, vm:GetBoneCount() do
		vm:ManipulateBoneScale( i, Vector(1, 1, 1) )
		vm:ManipulateBoneAngles( i, Angle(0, 0, 0) )
		vm:ManipulateBonePosition( i, Vector(0, 0, 0) )
	end
	
end
function SWEP:ViewModelDrawn()
	local vm = self.Owner:GetViewModel()
	if !IsValid(vm) then return end
	self:UpdateBonePositions(vm)
end
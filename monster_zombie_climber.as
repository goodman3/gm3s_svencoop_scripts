/*


Wall climber Zombie
Author  :Goodman3 (https://github.com/goodman3/gm3s_svencoop_scripts)
Contact :272992860@qq.com
Special Thanks: DrAbc (https://github.com/DrAbcrealone/Abc-AngelScripts-For-Svencoop)
===================================

A modified zombie that climbs walls to reach it's enemy.

Usage: 	MonsterZombieClimber::Register();

===================================

*/
namespace MonsterZombieClimber
{
	const array<string> pAttackHitSounds =
	{
		"zombie/claw_strike1.wav",
		"zombie/claw_strike2.wav",
		"zombie/claw_strike3.wav",
	};
	const array<string> pAttackMissSounds =
	{
		"zombie/claw_miss1.wav",
		"zombie/claw_miss2.wav",
	};
	const array<string> pAttackSounds =
	{
		"zombie/zo_attack1.wav",
		"zombie/zo_attack2.wav",
	};
	const array<string> pIdleSounds =
	{
		"zombie/zo_idle1.wav",
		"zombie/zo_idle2.wav",
		"zombie/zo_idle3.wav",
		"zombie/zo_idle4.wav",
	};
	const array<string> pAlertSounds =
	{
		"zombie/zo_alert10.wav",
		"zombie/zo_alert20.wav",
		"zombie/zo_alert30.wav",
	};
	const array<string> pPainSounds =
	{
		"zombie/zo_pain1.wav",
		"zombie/zo_pain2.wav",
	};

	CBaseEntity@ CheckTraceHullAttack( CBaseMonster@ pThis, float flDist, int iDamage, int iDmgType ) {
		TraceResult tr;

		if (pThis.IsPlayer()) {
			Math.MakeVectors( pThis.pev.angles );
		} else {
			Math.MakeAimVectors( pThis.pev.angles );
		}

		Vector vecStart = pThis.pev.origin;
		vecStart.z += pThis.pev.size.z * 0.5;
		Vector vecEnd = vecStart + (g_Engine.v_forward * flDist );

		g_Utility.TraceHull( vecStart, vecEnd, dont_ignore_monsters, head_hull, pThis.edict(), tr );
		
		if ( tr.pHit !is null ) {
			CBaseEntity@ pEntity = g_EntityFuncs.Instance( tr.pHit );
			if ( iDamage > 0 ) {
				pEntity.TakeDamage( pThis.pev, pThis.pev, iDamage, iDmgType );
			}
			return pEntity;
		}
		return null;
	}
	
/*
class CZombie : public CBaseMonster
{
public:

	void HandleAnimEvent( MonsterEvent_t *pEvent );

	// No range attacks

*/
	const string ZOMBIE_MODEL = "models/zombie.mdl";
    const int iHealth = 220;
	const float YAW_SPEED = 120;
	const float ZOMBIE_CLIMB_MAX_HEIGHT = 130 + VEC_HUMAN_HULL_MAX.z; // z = 72
	const float ZOMBIE_CLIMB_FORWARD_STEP = 40;
	const int ZOMBIE_FLINCH_DELAY = 2;
	const int ZOMBIE_AE_ATTACK_RIGHT = 1;
	const int ZOMBIE_AE_ATTACK_LEFT = 2;
	const int ZOMBIE_AE_ATTACK_BOTH = 3;
	const int g_iHealth = int(g_EngineFuncs.CVarGetFloat( "sk_zombie_health" ));
	const int g_iOneSlash = int(g_EngineFuncs.CVarGetFloat( "sk_zombie_dmg_one_slash" ));
	const int g_iBothSlash = int(g_EngineFuncs.CVarGetFloat( "sk_zombie_dmg_both_slash" ));
	const string Climb64Seq = "getup";
	const string Climb128Seq = "ventclimb";

	class CMonsterZombieClimber : ScriptBaseMonsterEntity
	{
	
		private int m_iSoundVolume = 1;
		private	int m_iVoicePitch = PITCH_NORM;	
		private float m_flNextFlinch;	
		private float m_flClimbProgress = 0;
		private Vector m_vecClimbPos;
		private string m_sCLimbSequence;
		
		//
		private int m_saved_movetype;
		private int m_saved_solid;
		private int m_saved_effects;
		
		
		void Spawn()
		{
		
			Precache( );
			
			g_EntityFuncs.SetModel(self, ZOMBIE_MODEL);
			g_EntityFuncs.SetSize(pev, VEC_HUMAN_HULL_MIN, VEC_HUMAN_HULL_MAX);
			
			pev.solid			        = SOLID_SLIDEBOX;
			pev.movetype		        = MOVETYPE_STEP;
			self.m_bloodColor	        = BLOOD_COLOR_GREEN;
			if(pev.health<=0)
			pev.health			        = iHealth;
			pev.view_ofs		        = VEC_VIEW;
			
			self.m_flFieldOfView        = 0.5;
			self.m_MonsterState		    = MONSTERSTATE_NONE;
			self.m_afCapability			= bits_CAP_DOORS_GROUP;
			self.m_FormattedName		= "Zombie";
			m_flClimbProgress		= 0;

			self.MonsterInit();
			
		}
		string RANDOM_SOUND_ARRAY(array<string> ary)
		{
			int i = Math.RandomLong(0,ary.length() - 1);
			return ary[i];
		}
		void PainSound( )
		{
			int pitch = 95 + Math.RandomLong(0,9);

			if (Math.RandomLong(0,5) < 2)
			g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, RANDOM_SOUND_ARRAY(pPainSounds), m_iSoundVolume, ATTN_NORM, 0, pitch );
		
		}
		void AlertSound( )
		{
			int pitch = 95 + Math.RandomLong(0,9);
			g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, RANDOM_SOUND_ARRAY(pAlertSounds), m_iSoundVolume, ATTN_NORM, 0, pitch );
		}		
		void IdleSound( )
		{
			int pitch = 100 + Math.RandomLong(-5,5);
			g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, RANDOM_SOUND_ARRAY(pIdleSounds), m_iSoundVolume, ATTN_NORM, 0, pitch );
		}		
		void AttackSound( )
		{
			int pitch = 100 + Math.RandomLong(-5,5);
			g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, RANDOM_SOUND_ARRAY(pAttackSounds), m_iSoundVolume, ATTN_NORM, 0, pitch );
		}

		void SetYawSpeed ( )
		{
			pev.yaw_speed = YAW_SPEED;
		}
		int	Classify ()
		{
			return	CLASS_ALIEN_MONSTER;
		}
		void Precache()
		{
			//BaseClass.Precache();
			g_Game.PrecacheModel(ZOMBIE_MODEL);
			for(uint i = 0; i < pAttackHitSounds.length();i++)
			{g_SoundSystem.PrecacheSound(pAttackHitSounds[i]);}	
			for(uint i = 0; i < pAttackMissSounds.length();i++)
			{g_SoundSystem.PrecacheSound(pAttackMissSounds[i]);}			
			for(uint i = 0; i < pAttackSounds.length();i++)
			{g_SoundSystem.PrecacheSound(pAttackSounds[i]);}			
			for(uint i = 0; i < pIdleSounds.length();i++)
			{g_SoundSystem.PrecacheSound(pIdleSounds[i]);}			
			for(uint i = 0; i < pAlertSounds.length();i++)
			{g_SoundSystem.PrecacheSound(pAlertSounds[i]);}			
			for(uint i = 0; i < pPainSounds.length();i++)
			{g_SoundSystem.PrecacheSound(pPainSounds[i]);}
			
		}	
		int IgnoreConditions ( )
		{
			int iIgnore = 0;
			
			if ((self.m_Activity == ACT_MELEE_ATTACK1) || (self.m_Activity == ACT_MELEE_ATTACK1))
			{	
				if (m_flNextFlinch >= g_Engine.time)
					iIgnore |= (bits_COND_LIGHT_DAMAGE|bits_COND_HEAVY_DAMAGE);
			}

			if ((self.m_Activity == ACT_SMALL_FLINCH) || (self.m_Activity == ACT_BIG_FLINCH))
			{
				if (m_flNextFlinch < g_Engine.time)
					m_flNextFlinch = g_Engine.time + ZOMBIE_FLINCH_DELAY;
			}

			return iIgnore;
			
		}
		
		bool CheckRangeAttack1 ( float flDot, float flDist )
		{ 
		return false;
		}
		bool CheckRangeAttack2 ( float flDot, float flDist )
		{ 
		return false;
		}
		int TakeDamage( entvars_t@ pevInflictor, entvars_t@ pevAttacker, float flDamage, int bitsDamageType )
		{
			// Take 30% damage from bullets
			if ( bitsDamageType == DMG_BULLET )
			{
				
				Vector vecDir = pev.origin - (pevInflictor.absmin + pevInflictor.absmax) * 0.5;
				vecDir = vecDir.Normalize();
				float flForce = self.DamageForce( flDamage );
				pev.velocity = pev.velocity + vecDir * flForce;
				flDamage *= 0.3;
			}
			
			// HACK HACK -- until we fix this.
			if ( self.IsAlive() )
				self.PainSound();
			return BaseClass.TakeDamage( pevInflictor, pevAttacker, flDamage, bitsDamageType );
		}
		void HandleAnimEvent( MonsterEvent@ pEvent )
		{
			switch( pEvent.event )
			{
				case ZOMBIE_AE_ATTACK_RIGHT:
				{
					CBaseEntity@ pHurt = CheckTraceHullAttack(self, 70, g_iOneSlash, DMG_SLASH );
					
					if ( pHurt !is null )
					{
					
						if ( pHurt.pev.flags & ( FL_MONSTER | FL_CLIENT ) != 0 )
						{
							pHurt.pev.punchangle.z = -18;
							pHurt.pev.punchangle.x = 5;
							pHurt.pev.velocity = pHurt.pev.velocity - g_Engine.v_right * 100;
						}
						// Play a random attack hit sound
						g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_WEAPON, RANDOM_SOUND_ARRAY(pAttackHitSounds), m_iSoundVolume, ATTN_NORM, 0,  100 + Math.RandomLong(-5,5) );
					}
					else
					{
					g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_WEAPON, RANDOM_SOUND_ARRAY(pAttackMissSounds), m_iSoundVolume, ATTN_NORM, 0,  100 + Math.RandomLong(-5,5) );
					}
					
					if(Math.RandomLong(0,1)>0)
					{
					AttackSound();
					}
				}
				break;				
				case ZOMBIE_AE_ATTACK_LEFT:
				{
					CBaseEntity@ pHurt = CheckTraceHullAttack(self, 70, g_iOneSlash, DMG_SLASH );
					
					if ( pHurt !is null )
					{
					
						if ( pHurt.pev.flags & ( FL_MONSTER | FL_CLIENT ) != 0 )
						{
							pHurt.pev.punchangle.z = 18;
							pHurt.pev.punchangle.x = 5;
							pHurt.pev.velocity = pHurt.pev.velocity - g_Engine.v_right * 100;
						}
						// Play a random attack hit sound
						g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_WEAPON, RANDOM_SOUND_ARRAY(pAttackHitSounds), m_iSoundVolume, ATTN_NORM, 0,  100 + Math.RandomLong(-5,5) );
					}
					else
					{
					g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_WEAPON, RANDOM_SOUND_ARRAY(pAttackMissSounds), m_iSoundVolume, ATTN_NORM, 0,  100 + Math.RandomLong(-5,5) );
					}
					
					if(Math.RandomLong(0,1)>0)
					{
					AttackSound();
					}
				}
				break;
				case ZOMBIE_AE_ATTACK_BOTH:
				{
					CBaseEntity@ pHurt = CheckTraceHullAttack(self, 70, g_iBothSlash, DMG_SLASH );
					
					if ( pHurt !is null )
					{
					
						if ( pHurt.pev.flags & ( FL_MONSTER | FL_CLIENT ) != 0 )
						{
							pHurt.pev.punchangle.x = 5;
							pHurt.pev.velocity = pHurt.pev.velocity - g_Engine.v_right * 100;
						}
						// Play a random attack hit sound
						g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_WEAPON, RANDOM_SOUND_ARRAY(pAttackHitSounds), m_iSoundVolume, ATTN_NORM, 0,  100 + Math.RandomLong(-5,5) );
					}
					else
					{
					g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_WEAPON, RANDOM_SOUND_ARRAY(pAttackMissSounds), m_iSoundVolume, ATTN_NORM, 0,  100 + Math.RandomLong(-5,5) );
					}
					
					if(Math.RandomLong(0,1)>0)
					{
					AttackSound();
					}
				}
				break;
				
				default:
					BaseClass.HandleAnimEvent( pEvent );
					break;
			}
		}
		void RouteNew()
		{
			self.m_Route(0).iType		= 0;
			self.m_iRouteIndex	= 0;
		}
		void MoveToLocation(Activity movementAct, float waitTime, Vector goal){
			self.m_movementActivity = movementAct;
			self.m_moveWaitTime = waitTime;
			
			//self.m_movementGoal = bits_MF_TO_LOCATION;
			self.m_vecMoveGoal = goal;
			self.m_vecEnemyLKP = goal;
			
			RouteNew();
		}
		bool WalkCheck(Vector pos,Vector dir,float flDist){
			Vector lastPos = pev.origin;
			g_EntityFuncs.SetOrigin (self, pos);
			int oldType = pev.movetype;
			int result = g_EngineFuncs.WalkMove(self.edict(), g_EngineFuncs.VecToYaw(dir), flDist, WALKMOVE_CHECKONLY);
			g_EntityFuncs.SetOrigin (self, lastPos);
			return result == 0 ? true : false;
		}

		/*
		Fire a Vector to target, try to reach edge - goodman3
		*/
		void MoveToEdge(bool detectEnemy){
			Vector dir;
			if(detectEnemy && self.m_hEnemy.IsValid()){
				dir = self.m_hEnemy.GetEntity().pev.origin;
				dir.z = pev.origin.z;
			} else {	
				dir =  pev.origin + g_Engine.v_forward * 6000;
			}
			TraceResult tr;
			g_Utility.TraceLine( pev.origin, dir, ignore_monsters, self.edict(), tr );
			Vector vecEndPos;
			if( tr.flFraction < 1.0 )
			{
				if( tr.pHit !is null )
				{
					CBaseEntity@ pHit = g_EntityFuncs.Instance( tr.pHit );
					vecEndPos = pHit.pev.origin;
					if( pHit is null || pHit.IsBSPModel() )
						vecEndPos = tr.vecEndPos;
				}
			} else {
				vecEndPos =  dir;
			}
			vecEndPos = vecEndPos - g_Engine.v_forward * ZOMBIE_CLIMB_FORWARD_STEP/2;
			MoveToLocation(ACT_WALK, 0, vecEndPos);
		}
		bool isClimbable(Vector angleVec){
			if(WalkCheck(pev.origin,angleVec,ZOMBIE_CLIMB_FORWARD_STEP)){
				TraceResult tr;
				Vector dst = pev.origin + angleVec * ZOMBIE_CLIMB_FORWARD_STEP;
				Vector up = dst + Vector(0,0,ZOMBIE_CLIMB_MAX_HEIGHT);
				g_Utility.TraceHull( up, dst, dont_ignore_monsters,human_hull, self.edict(), tr );
				Vector vecEndPos;
				if( tr.pHit !is null )
				{
					CBaseEntity@ pHit = g_EntityFuncs.Instance( tr.pHit );
					vecEndPos = pHit.pev.origin;
					if( pHit is null || pHit.IsBSPModel() ){
						vecEndPos = tr.vecEndPos;
					} else {
						//a entity, ingore it
						return false;
					}
				} else {
					return false;
				}
				
				float distance = vecEndPos.z - pev.origin.z - VEC_HUMAN_HULL_MAX.z / 2;
				if(distance < 16){
					return false;
				} else if( distance <98)	{
					m_sCLimbSequence = 	Climb64Seq;
				} else if( distance < ZOMBIE_CLIMB_MAX_HEIGHT - 16) {
					m_sCLimbSequence = 	Climb128Seq;
				} else {
					return false;
				}
				
				vecEndPos.z -= VEC_HUMAN_HULL_MAX.z / 2;
				m_vecClimbPos = vecEndPos;
				return true;
			
			}
			 else {
				return false;
			}
			
			
		}
		void PerformClimb(){
			if(  pev.flags & FL_ONGROUND != 0 ){
				pev.flags &= FL_ONGROUND;
				self.m_flWaitFinished =  g_Engine.time + 2;
				
				
				self.SetSequenceByName(m_sCLimbSequence);
				g_EntityFuncs.SetOrigin (self, m_vecClimbPos);	
				RouteNew();
					
				self.TaskComplete();
				pev.frame = 0; 
				self.m_IdealMonsterState = MONSTERSTATE_NONE;
				m_flClimbProgress = 1;
			}
		}
	
		Schedule@ GetScheduleOfType ( int Type )
		{	
			switch	( Type )
			{
				case SCHED_CHASE_ENEMY:{
					Math.MakeVectors ( pev.angles );
					if(isClimbable(g_Engine.v_forward)){
						PerformClimb();
						return slZombieAfterClimb;
					}
					return BaseClass.GetScheduleOfType( Type );
				}
				case SCHED_CHASE_ENEMY_FAILED:
					Math.MakeVectors ( pev.angles );
					if(isClimbable(g_Engine.v_forward)){
						PerformClimb();
						return slZombieAfterClimb;
					} 
					else {
						MoveToEdge(false);
						return slZombieWaitForClimb;
					}
					
				
			}
			return BaseClass.GetScheduleOfType( Type );
		}
		void Blocked(CBaseEntity@ pOther){
			Math.MakeVectors ( pev.angles );
			if(isClimbable(g_Engine.v_forward)){
				PerformClimb();
			} 
		}
		void PrescheduleThink ()
		{
			if(m_flClimbProgress>=1){
				pev.flags &= FL_ONGROUND;
				self.m_flWaitFinished =  g_Engine.time + 2;
				self.m_IdealMonsterState = MONSTERSTATE_NONE;	
				self.SetSequenceByName(m_sCLimbSequence);
			} if(m_flClimbProgress>0){
				self.m_IdealMonsterState = MONSTERSTATE_NONE;	
				m_flClimbProgress -= 0.1;
			} 
			if(m_flClimbProgress<=0 && self.m_MonsterState == MONSTERSTATE_NONE && self.m_fSequenceFinished){
				self.m_IdealMonsterState = MONSTERSTATE_COMBAT;	
			} 
			
		}
	}
	array<ScriptSchedule@>@ monster_expcrab_schedules;
		
		ScriptSchedule slZombieWaitForClimb (
				//bits_COND_ENEMY_OCCLUDED	|
				bits_COND_NO_AMMO_LOADED,
				0,
				"ZombieWaitForClimb"
		);		
		ScriptSchedule slZombieAfterClimb (
				//bits_COND_ENEMY_OCCLUDED	|
				bits_COND_NO_AMMO_LOADED,
				0,
				"ZombieAfterClimb"
		);

		void InitSchedules()
		{
			slZombieWaitForClimb.AddTask( ScriptTask(TASK_GET_PATH_TO_ENEMY_LKP) );
			slZombieWaitForClimb.AddTask( ScriptTask(TASK_WALK_PATH) );
			slZombieWaitForClimb.AddTask( ScriptTask(TASK_SET_ACTIVITY, float(ACT_IDLE)) );
			slZombieWaitForClimb.AddTask( ScriptTask(TASK_WAIT, 1.0) );
			slZombieAfterClimb.AddTask( ScriptTask(TASK_WAIT, 1.0) );
			slZombieAfterClimb.AddTask( ScriptTask(TASK_TURN_RIGHT) );
			slZombieAfterClimb.AddTask( ScriptTask(TASK_TURN_RIGHT) );
			slZombieAfterClimb.AddTask( ScriptTask(TASK_TURN_RIGHT) );
			array<ScriptSchedule@> scheds = {slZombieWaitForClimb,slZombieAfterClimb};
			@monster_expcrab_schedules = @scheds;
			//g_taskWait = ScriptTask(TASK_WAIT, 1.0);
		}
	void Register()
	{
		InitSchedules();
		g_CustomEntityFuncs.RegisterCustomEntity( "MonsterZombieClimber::CMonsterZombieClimber", "monster_zombie_climber" );
	}
}
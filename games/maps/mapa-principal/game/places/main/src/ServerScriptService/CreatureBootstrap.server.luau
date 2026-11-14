--!strict
-- Staging-only activation; the reviewed model is stored with the Place.
local root=script.Parent:WaitForChild("CreatureFramework")
local function get(name:string):any return require(root:WaitForChild(name) :: ModuleScript) end
local flags=get("FeatureFlags")
if not flags.Enabled then return end
local Registry=get("CreatureRegistry")
local Director=get("SpawnDirector")
local Service=get("FaunaService")
local BookRuntime=get("BookRuntime")
local Gameplay=get("BookGameplay")
local Remote=get("BookServer")
local CombatWorld=get("CombatWorld")
local combatState=CombatWorld.new(workspace,get("CombatSpatialIndex"),get("CombatRules"),64)
local deps={factory=get("CreatureAgentFactory"),profiles=get("CombatProfiles"),combatBrain=get("CombatBrain"),combatWorld=CombatWorld,combatState=combatState,combatAdapter=get("CombatAdapter"),targetSelector=get("CombatTargets"),registry=Registry,brain=get("MobBrain"),kernel=get("AIKernel"),escape=get("EscapePlanner"),adapter=get("RobloxMobAdapter"),agent=get("AgentRuntime"),population=get("PopulationBudget"),spawn=get("SpawnPolicy"),biomes=get("BiomeRegions"),food=get("FoodSites"),scheduler=get("SimulationBudget"),director=Director}
local assets=assert(game:GetService("ServerStorage"):WaitForChild("RSCreatureAssets",10),"Missing reviewed creature assets")
local stored=assert(assets:WaitForChild("ChickenV2",10),"Missing ChickenV2 template")
assert(stored:IsA("Model") and stored:GetAttribute("RSAssetId")==Registry.get("210080").modelAssetId,"Chicken template identity")
local template=stored:Clone()
assert(template.Parent==nil)
local folder=Instance.new("Folder");folder.Name="RSCreatures";folder.Parent=workspace
local fauna=Service.new(deps,template,folder,math.random(1,2147483646))
local books=BookRuntime.new({persistence=get("BookPersistence"),core=get("BookCore"),registry=Registry,store=get("BookDataStore")})
local events=Gameplay.new(books.book,get("BookPersistence"),fauna.director,BookRuntime.validateInteraction)
local transport=Remote.new({registry=Registry,persistence=get("BookPersistence"),developer=get("DeveloperPolicy"),summon=get("SummonPlan"),director=Director,gameplay=Gameplay},fauna,books.book,events,flags)
fauna.director.d.onSpawn=function(id:string,record:any)Remote.attach(transport,id,record)end
BookRuntime.start(books);Remote.start(transport);Service.start(fauna)
game:BindToClose(function()Remote.stop(transport);Service.stop(fauna);template:Destroy();folder:Destroy()end)

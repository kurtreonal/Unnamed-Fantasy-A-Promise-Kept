"""Authoring source for the campaign's stable-ID content catalog."""
import json
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / 'Game' / 'Data'

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    items = {}
    for family, names in {
        'sword':['Weathered Sword','Riversteel Sword','Dawnkeeper'],
        'spear':['Ashwood Spear','Miner’s Pike','Lantern Lance'],
        'bow':['Willow Bow','Hawthorn Bow','Far Horizon'],
        'staff':['Hazel Staff','Moonstone Staff','Springlight'],
    }.items():
        for tier, name in enumerate(names, 1):
            items[f'{family}_{tier}'] = dict(name=name,kind='weapon',family=family,tier=tier,attack=8+tier*5,price=tier*tier*100,description=f'A reliable {family}. Tier {tier}; its strength comes from careful preparation.')
    for key,name,kind,price,extra in [
        ('cloth_coat','Mended Coat','armor',60,{'defense':2}),('leather_coat','Travel Coat','armor',240,{'defense':5}),('warden_coat','Warden Coat','armor',600,{'defense':8}),
        ('ribbon','Rin’s Ribbon','accessory',0,{'max_hp':15}),('charm','Carved Charm','accessory',180,{'max_hp':25}),('locket','Promise Locket','accessory',400,{'max_hp':40}),
        ('potion','Restorative Tea','consumable',20,{'heal':45}),('grain','Oats','ingredient',4,{}),('vegetable','Root Vegetables','ingredient',5,{}),('honey','Wild Honey','ingredient',8,{}),
        ('herb','Meadow Herbs','ingredient',6,{}),('moss','Silver Moss','quest',0,{}),('moonstone','Moonstone Shard','quest',0,{}),('sunpetal','Sunpetal','quest',0,{}),
        ('forest_seal','Forester’s Record','quest',0,{}),('mine_seal','Physician’s Record','quest',0,{}),('ruin_seal','Sanctuary Record','quest',0,{}),('medicine','Herbal Medicine','quest',0,{}),('cure','Elixir of Spring','quest',0,{})]:
        items[key] = dict(name=name,kind=kind,price=price,description=name+'.',**extra)
    activities = []
    for key,name,hours,aff,health,hint in [
        ('talk','Sit and listen',1,2,0,'Ask what she wants to share, rather than deciding for her.'),
        ('read','Read together',1,2,1,'The atlas has a pressed flower between its pages.'),
        ('garden','Tend the windowsill',1,2,2,'Rin has ideas for a garden of her own.'),
        ('cook','Cook together',1,2,2,'Let her choose the seasoning.'),
        ('walk','A short village walk',1,2,2,'An easy pace is still a journey.'),
        ('stargaze','Watch the evening stars',1,2,1,'Some promises point beyond the village gate.'),
        ('repair','Mend something together',1,2,0,'A chair, a coat, a life: repair takes patience.'),
        ('research','Study the treatment notes',1,1,0,'Rin can recognize patterns the village healers missed.'),
        ('game','Play a quiet board game',1,2,1,'Winning is less important than making time.'),
        ('tea','Share herbal tea',1,2,3,'Comfort need not be expensive.')]:
        activities.append(dict(id=key,name=name,hours=hours,affection=aff,health=health,hint=hint))
    recipes = [
        dict(id='porridge',name='Warm porridge',cost=0,ingredients={},health=3,affection=1,description='A dependable pantry meal. Always available; varied meals offer more support.'),
        dict(id='soup',name='Root vegetable soup',cost=0,ingredients={'vegetable':2},health=13,affection=2,description='Warmth that lasts into the afternoon.'),
        dict(id='bread',name='Honey oat bread',cost=0,ingredients={'grain':2,'honey':1},health=12,affection=3,description='Rin likes the crisp edges best.'),
        dict(id='stew',name='Harvest stew',cost=0,ingredients={'vegetable':2,'herb':1},health=18,affection=2,description='A generous meal for a cold day.'),
        dict(id='tea',name='Honey herb infusion',cost=0,ingredients={'herb':1,'honey':1},health=10,affection=2,description='Gentle on difficult mornings.'),
        dict(id='feast',name='A small celebration',cost=0,ingredients={'grain':2,'vegetable':2,'honey':1},health=22,affection=4,description='A meal worth preparing together.'),
    ]
    quests = []
    mainquests = [
        ('m01','A Morning of Our Own','talk',1,1,'Ask Rin what she hopes this spring will bring.',''),
        ('m02','Silver Beneath the Leaves','gather:moss',3,1,'Gather silver moss from the forest.','m01'),
        ('m03','The Old Forester','boss:0',1,1,'Defeat the Bramble Warden and recover the forester’s record.','m02'),
        ('m04','Two Sets of Eyes','activity:research',2,8,'Study the forester’s notes together on two occasions.','m03'),
        ('m05','Light in the Mine','gather:moonstone',3,8,'Find moonstone in the abandoned mine.','m04'),
        ('m06','What the Earth Remembers','boss:1',1,8,'Defeat the Hollow Keeper and recover the physician’s record.','m05'),
        ('m07','A Hand in the Margins','activity:read',1,15,'Read the physician’s notes with Rin.','m06'),
        ('m08','Flowers Without Sun','gather:sunpetal',3,15,'Gather sunpetals in the sanctuary.','m07'),
        ('m09','The Last Custodian','boss:2',1,15,'Defeat the Pale Custodian and recover the sanctuary record.','m08'),
        ('m10','A Gentler Remedy','craft:medicine',1,22,'Prepare herbal medicine at home.','m09'),
        ('m11','Her Answer','activity:research',1,22,'Review the final formula with Rin.','m10'),
        ('m12','Spring, At Last','craft:cure',1,22,'Combine the three records and gathered ingredients into the Elixir of Spring.','m11'),
    ]
    for key,title,event,count,day,description,requires in mainquests:
        quests.append(dict(id=key,title=title,event=event,count=count,day=day,description=description,requires=requires,kind='main',reward=60))
    for i,(title,event,count,description) in enumerate([
        ('A Pantry for Two','gather:herb',3,'Bring home herbs for the village pantry.'),('The Broken Fence','kill',5,'Clear five creatures from the forest road.'),('Something Warm','meal',3,'Share three meals.'),
        ('An Evening Atlas','activity:read',2,'Read together twice.'),('A Useful Find','chest',3,'Open three expedition chests.'),('The Quiet Table','activity:game',2,'Make time for two board games.'),
        ('A Place to Grow','activity:garden',3,'Tend the windowsill on three occasions.'),('Borrowed Courage','activity:walk',2,'Take two village walks.'),('Small Repairs','activity:repair',2,'Repair two things together.'),
        ('Under One Sky','activity:stargaze',3,'Share three evenings under the stars.'),('The Long Road Home','return',5,'Return safely from five expeditions.'),('A Taste of Spring','meal:feast',1,'Prepare a small celebration.')],1):
        quests.append(dict(id=f's{i:02}',title=title,event=event,count=count,day=1+((i-1)//3)*7,description=description,requires='',kind='side',reward=45))
    # Every event is individually authored; the choice is committed only once.
    story = [
        ('The Chair by the Window','talk',1,'',[
            'Rin|You moved the chair again.', 'You|The morning light reaches this corner.', 'Rin|So does the draft. I can choose where I sit, you know.', 'You|Then where would you like it?', 'Rin|Beside yours. Just for breakfast.', 'Narrator|It is a small answer, but you finally hear the question beneath it.'], [('Then beside mine it stays.',3,4,'respect'),('I will fetch a blanket too.',2,0,'care')]),
        ('The Crisp Edges','cook',2,'', ['Rin|You always leave the darkest piece of bread for yourself.','You|I thought you liked the soft middle.','Rin|I like the crisp edges. You never asked.','You|Then we have eight years of breakfasts to correct.','Rin|Start with this one.','Narrator|She breaks the toast in two and gives you the larger half.'], [('Remember her preference.',3,4,'preference_bread'),('Ask her to teach you her recipe.',3,3,'cooking_memory')]),
        ('A Map Folded Twice','read',3,'travel1',['Rin|This atlas is older than we are.','You|Most of the roads are probably gone.','Rin|That does not mean the places are. Look: a town where the lanterns float on the river.','You|Would you like to see it?','Rin|I would like to be asked when we are not talking about medicine.','Narrator|You leave a ribbon between the pages.'], [('We can want something beyond a cure.',3,5,'travel1'),('Tell me about another place.',2,2,'atlas')]),
        ('Rain on the Windowsill','garden',4,'personal1',['Rin|The rosemary is leaning toward the glass.','You|I could move it outside.','Rin|Not yet. It needs to learn the weather a little at a time.','You|You sound like the gardener your father used to call you.','Rin|I would rather be the gardener I might become.','Narrator|Together, you turn the pot toward the light.'], [('Then let us plan your garden.',3,4,'personal1'),('You already know more than I do.',2,2,'encouragement')]),
        ('An Honest Return','talk',5,'',['Rin|Did you get hurt today?','You|Only a scratch.','Rin|You say that before you even look at the bandage.','You|I thought worrying you would make things harder.','Rin|Guessing is harder. Let me know the person who comes home.','Narrator|You set your pack down between you instead of hiding it by the door.'], [('Tell her what happened.',3,5,'honesty'),('Promise to bring difficult news home too.',3,4,'honesty')]),
        ('A Game Without Winners','game',6,'',['Rin|You are letting me win.','You|I am considering my strategy.','Rin|Your strategy has lost four pieces in a row.','You|Perhaps I like your victorious expression.','Rin|Then earn it honestly.','Narrator|Her laugh interrupts the rain. For a while, neither of you listens for anything else.'], [('Play properly, and stay for another round.',3,5,'game_memory'),('Ask for a lesson.',2,3,'patience')]),
        ('Letters in the Margin','research',8,'research1',['Rin|The forester wrote the symptoms in reverse order.','You|The healer said that page was useless.','Rin|He read the list. He did not read the dates.','You|You think the moss treats the fever, not the cause.','Rin|I think we should find out together.','Narrator|For the first time, her handwriting joins yours in the treatment book.'], [('Make Rin a partner in the research.',3,5,'research1'),('Ask her to explain every step.',2,3,'research1')]),
        ('The Mended Sleeve','repair',9,'',['Rin|Hold still. The thread keeps catching.','You|You do not have to mend my coat.','Rin|And you do not have to carry every difficult thing yourself.','You|That is not quite the same.','Rin|No. But it is where I can start.','Narrator|The repaired seam is crooked and stronger than it was.'], [('Thank her without arguing.',3,4,'accept_help'),('Offer to repair her old chair next.',2,3,'repair_memory')]),
        ('The Long Way to the Well','walk',10,'personal2',['Rin|Do not slow down before I ask.','You|I was watching the road.','Rin|You were watching me.','You|Is that so terrible?','Rin|Only if it means you miss the flowers.','Narrator|At the well she rests, and tells you which seeds she wants to plant.'], [('Ask her to choose the route next time.',3,5,'personal2'),('Sit and watch the village together.',2,3,'village_memory')]),
        ('Two Cups Cooling','tea',11,'',['Rin|If they find the cure, will you still sit here?','You|Of course.','Rin|You answered very quickly.','You|I have had years to think about this chair.','Rin|I meant with me.','Narrator|The steam has faded. Neither of you reaches for the cups.'], [('I want the ordinary days with you.',3,7,'romance1'),('You will never have to earn my company.',3,2,'companionship')]),
        ('A River of Paper Lanterns','read',12,'travel2',['Rin|I tried drawing that river town.','You|The lanterns look like stars.','Rin|They are supposed to. You write a wish on the paper first.','You|What would yours say?','Rin|Ask me when we get there.','Narrator|She folds the drawing small enough to fit in your coat pocket.'], [('Keep the drawing and promise a journey.',3,6,'travel2'),('Tell her your own wish.',2,4,'wish_memory')]),
        ('A Seat at the Table','cook',13,'',['Rin|Let me stir.','You|The pot is heavy.','Rin|Then hold the handle. I can still stir.','You|We make a convincing kitchen team.','Rin|A team requires you to listen sometimes.','Narrator|You hold the handle. She seasons the soup. Dinner tastes like both of you.'], [('Let her lead the cooking.',3,5,'shared_work'),('Write down the recipe together.',2,4,'recipe_memory')]),
        ('The Name of the Illness','research',15,'research2',['Rin|The physician called it a failure of the body.','You|There may have been no better name.','Rin|There should have been. I have spent years hearing that I am failing.','You|You have survived every one of those years.','Rin|Then write that down too.','Narrator|You turn the page and leave room for a better account.'], [('Ask Rin to name the research journal.',3,6,'research2'),('Write: a person, never a diagnosis.',3,5,'research2')]),
        ('The Empty Place','talk',16,'',['Rin|I miss my father most when something good happens.','You|I still remember what I promised him.','Rin|I know. But I did not ask you to spend your life repaying a dead man.','You|I am not here only because of him.','Rin|Then someday, tell me why you stayed.','Narrator|Her hand rests near yours, close enough to choose.'], [('Take her hand and tell her you love her.',4,10,'romance2'),('Tell her she is your closest friend.',3,0,'friendship')]),
        ('Seeds for Next Year','garden',17,'personal3',['Rin|I ordered seeds that will not flower until next year.','You|That sounds optimistic.','Rin|It sounds like a decision.','You|Where will you put them?','Rin|At the village greenhouse. I asked about helping there.','Narrator|The future arrives as a paper packet on the table.'], [('Support the greenhouse she chose.',3,6,'personal3'),('Offer help when she asks for it.',3,4,'personal3')]),
        ('An Unfinished Constellation','stargaze',18,'travel3',['Rin|You connected the wrong stars.','You|I was making a new constellation.','Rin|What is it called?','You|The Road We Have Not Taken.','Rin|Then leave it unfinished. We might find more stars later.','Narrator|She leans against you, warm beneath the evening shawl.'], [('Ask her to travel with you after treatment.',3,8,'travel3'),('Stay until she is ready to go inside.',3,3,'stars_memory')]),
        ('What Courage Looks Like','game',19,'',['Rin|The hero in this game never stops to eat.','You|Perhaps that is why he keeps losing.','Rin|Perhaps someone should tell him that coming home is an achievement.','You|Is that your professional advice?','Rin|Yes. From an expert in waiting.','Narrator|You set the pieces aside before the candles burn low.'], [('Promise time together even during the final search.',3,6,'home_promise'),('Ask how waiting has felt for her.',3,5,'listening')]),
        ('No More Brave Faces','tea',20,'',['Rin|I am afraid the treatment will not work.','You|So am I.','Rin|You are allowed to say that?','You|I am learning.','Rin|Then I am afraid, and I am hopeful. Both can stay.','Narrator|You sit with the uncertainty until it becomes something you can carry together.'], [('Face the uncertainty together.',4,7,'shared_fear'),('Ask what would make tomorrow easier.',3,4,'gentleness')]),
        ('Her Answer','research',22,'research3',['Rin|I have read every version of the formula.','You|And?','Rin|I want to try. Not because you promised. Because I want a life after this.','You|Tell me what you need.','Rin|The truth, someone beside me, and the right to change my mind.','Narrator|You place the final page in front of her. She signs her own name.'], [('Respect her treatment decision.',4,8,'research3'),('Promise to listen at every step.',3,6,'research3')]),
        ('A Door Without a Debt','repair',23,'',['Rin|The latch finally opens without a fight.','You|It only took us eight years.','Rin|Some things take practice.','You|Is this still about the door?','Rin|I want to stay because I choose to. I want you to know that.','Narrator|The repaired door stands open to the spring air.'], [('Tell her you choose her too.',4,9,'romance3'),('Tell her this will always be her home.',3,2,'home_memory')]),
        ('A Small Celebration','cook',24,'',['Rin|What are we celebrating?','You|We made it through another week.','Rin|That is enough?','You|It should have been enough sooner.','Rin|Then give me the crisp piece.','Narrator|There are no guests, no speeches, and more than enough reasons to set two places.'], [('Celebrate the life you already share.',3,6,'celebration'),('Ask her to name the next occasion.',3,4,'next_occasion')]),
        ('The Shape of Tomorrow','walk',25,'',['Rin|When I can walk farther, I will still want to stop here.','You|At the old well?','Rin|At a place we reached slowly.','You|We can come back as often as you like.','Rin|And leave as often as I like.','Narrator|You realize that both promises matter.'], [('Make room for both staying and leaving.',4,7,'freedom'),('Ask where she wants to go first.',3,5,'future_memory')]),
        ('Not an Obligation','talk',26,'',['Rin|If we call this love, it must be ours.','You|It is.','Rin|Not an illness. Not your promise. Not gratitude for being looked after.','You|I love your impossible questions and your terrible board-game victories.','Rin|Good. Those will survive a cure.','Narrator|She takes your hand before asking the question.'], [('Ask to build a life together, as equals.',4,12,'commitment'),('Keep the closeness you have as friends.',3,0,'friendship')]),
        ('Before the Morning','stargaze',27,'',['Rin|Tomorrow feels very close.','You|We do not have to solve it tonight.','Rin|I know. Tonight, tell me something ordinary.','You|The rosemary needs a larger pot.','Rin|Then that is our first plan.','Narrator|Beyond the window, the road waits. Inside, there is still time for one more cup of tea.'], [('Stay, and make one ordinary plan.',4,8,'last_evening'),('Share the wish you have been carrying.',3,7,'last_wish')]),
    ]
    events=[]
    for i,(title,activity,day,chain,lines,choices) in enumerate(story,1):
        events.append(dict(id=f'e{i:02}',title=title,activity=activity,day=day,chain=chain,critical=True,lines=lines,choices=[dict(text=t,affection=a,love=l,flag=f) for t,a,l,f in choices]))
    regions=[dict(id=0,name='Willowmere Woods',day=1,material='moss',boss='Bramble Warden',seal='forest_seal',palette=['#59624c','#75755a','#383e35']),dict(id=1,name='The Hollow Mine',day=8,material='moonstone',boss='Hollow Keeper',seal='mine_seal',palette=['#4c5359','#73736e','#2c3036']),dict(id=2,name='Sanctuary of First Light',day=15,material='sunpetal',boss='Pale Custodian',seal='ruin_seal',palette=['#67625c','#9b907c','#3c4140'])]
    enemies=[]
    for key,name,region,hp,atk,speed,style in [('slug','Moss Slug',0,24,7,42,'melee'),('thorn','Thornling',0,36,9,58,'melee'),('moth','Briar Moth',0,22,8,70,'ranged'),('crawler','Stone Crawler',1,48,11,55,'melee'),('shade','Mine Shade',1,35,12,70,'ranged'),('sentinel','Hollow Sentinel',1,65,14,42,'charge'),('wisp','Pale Wisp',2,46,13,72,'ranged'),('keeper','Lost Acolyte',2,70,16,60,'charge')]:
        enemies.append(dict(id=key,name=name,region=region,hp=hp,attack=atk,speed=speed,style=style))
    data=dict(characters={'rin':{'display_name':'Rin','asset_name':'Asami','age':17,'role':'high_school_student'},'player':{'age':17,'role':'high_school_classmate'}},chapters=['Ordinary Promises','What We Leave Unsaid','A Promise Shared','Tomorrow Together'],items=items,activities=activities,recipes=recipes,quests=quests,events=events,regions=regions,enemies=enemies)
    (OUT/'campaign.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    timelines=OUT.parent/'Timelines';timelines.mkdir(exist_ok=True)
    for event in events:
        lines=['# '+event['title'],'# Dialogic source. Line signals drive the cinematic layout and save checkpoints.']
        for index,line in enumerate(event['lines']):
            speaker,words=line.split('|',1)
            lines += [f'label line_{index}',f'[signal arg="line:{index}:{speaker}:protected"]',words]
        (timelines/(event['id']+'.dtl')).write_text('\n'.join(lines)+'\n',encoding='utf8')
    print('Authored',len(quests),'quests,',len(events),'relationship events,',len(items),'items')

if __name__=='__main__':main()

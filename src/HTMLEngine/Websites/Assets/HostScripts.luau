--!strict
-- Shared sources; documents receive only their actual script dependencies.
local sources = {
	["http://localhost:8000/wttg2-config.js"] = [==[
window.WTTG2_PORT = {"pages":["/blank.html","/ascii/index.html","/bewarned/aliens.html","/bewarned/arch.html","/bewarned/index.html","/bewarned/whydie.html","/brutal/index.html","/brutal/signup.html","/BugChaser/faq.html","/BugChaser/index.html","/BugChaser/join.html","/BugChaser/noid.html","/BugChaser/store.html","/cleanup/burial.html","/cleanup/freezing.html","/cleanup/index.html","/CreepyFace/index.html","/CryBitch/index.html","/CryBitch/login.html","/deepJournal/index.html","/deepJournal/page2.html","/deepJournal/page3.html","/DocBreather/index.html","/DocLucas/index.html","/DocMem/index.html","/DocNode/index.html","/DocNoir/index.html","/DocPolice/index.html","/DocStack/index.html","/DocZoneWall/index.html","/dontwasteit/index.html","/dontwasteit/no.html","/dontwasteit/yes.html","/dronespy/index.html","/dronespy/spyforme.html","/dronespy/videos.html","/evidencelocker/confiscated.html","/evidencelocker/contribute.html","/evidencelocker/index.html","/evidencelocker/leaked.html","/evidencelocker/purchase.html","/EvilCollection/ab.html","/EvilCollection/ab2.html","/EvilCollection/baby.html","/EvilCollection/chat.html","/EvilCollection/creepypics.html","/EvilCollection/index.html","/EvilCollection/link.html","/EvilCollection/memes.html","/EvilCollection/pics.html","/EvilCollection/randompics.html","/eye/index.html","/fatherdonald/index.html","/fatherdonald/join.html","/FootDoctor/homemade.html","/FootDoctor/index.html","/FootDoctor/myfavoritefeet.html","/FootDoctor/sendmepics.html","/ForgiveMe/confess.html","/ForgiveMe/index.html","/fortuneCookie/index.html","/genshare/index.html","/granddaddy/contact.html","/granddaddy/error.html","/granddaddy/gallery.html","/granddaddy/index.html","/GrandmasFantasy/index.html","/GrandmasFantasy/older.html","/Heirloom/containers.html","/Heirloom/error.html","/Heirloom/index.html","/Heirloom/order.html","/Heirloom/pgpkey.html","/Heirloom/quality.html","/Heirloom/specials.html","/Heirloom/walletid.html","/HiddenPleasures/buy.html","/HiddenPleasures/index.html","/HiddenPleasures/message.html","/HiddenPleasures/range1.html","/HiddenPleasures/range2.html","/HiddenPleasures/range3.html","/HiddenPleasures/range4.html","/HiddenPleasures/range5.html","/HiddenPleasures/requestsale.html","/HiddenPleasures/signin.html","/Iamhere/index.html","/IloveCats/contact.html","/IloveCats/index.html","/IloveCats/mycats.html","/isevil/index.html","/keepsake/index.html","/killforme/index.html","/killforme/instructions.html","/killforme/targets.html","/littleFriends/error.html","/littleFriends/index.html","/milksupply/index.html","/milksupply/milkpictures.html","/mortalmasks/how.html","/mortalmasks/index.html","/mortalmasks/order.html","/mutilation/index.html","/mutilation/join.html","/mutilation/login.html","/mutilation/nowallet.html","/mydaughter/index.html","/mygut/buy.html","/mygut/contact.html","/mygut/index.html","/mygut/shop.html","/mygut/special.html","/Myriad/index.html","/NotFound/index.html","/numbers/index.html","/numbers2/index.html","/numberStation/index.html","/oneless/index.html","/pantySales/index.html","/PayToRape/faq.html","/PayToRape/index.html","/PayToRape/pay.html","/RandomSite/gateopen.html","/RandomSite/index.html","/replyThread/index.html","/sacrifice/enter.html","/sacrifice/index.html","/sacrifice/join.html","/sacrifice/walk.html","/satan/index.html","/satan/join.html","/ScreamBitch/index.html","/ThanksForVisiting/babyshrimp.html","/ThanksForVisiting/bar.html","/ThanksForVisiting/black.html","/ThanksForVisiting/creepy.html","/ThanksForVisiting/donttalktome.html","/ThanksForVisiting/evilmonster.html","/ThanksForVisiting/face.html","/ThanksForVisiting/fakemain.html","/ThanksForVisiting/index.html","/ThanksForVisiting/numbers.html","/ThanksForVisiting/posture.html","/ThanksForVisiting/slide.html","/ThanksForVisiting/slide2.html","/TheBlackWaves/index.html","/thebombmaker/index.html","/thedollmaker/enter.html","/thedollmaker/index.html","/TheEndForNY/index.html","/TheGrey/centrum.html","/TheGrey/inanis.html","/TheGrey/index.html","/TheGrey/interius.html","/TheGrey/latus.html","/thehall/index.html","/TheLightWithin/index.html","/TheLightWithin/saved.html","/TheLoogaroo/index.html","/ThePrey/index.html","/thethree/index.html","/TutKeyDis/index.html","/tutVid1/index.html","/tutVid2/index.html","/tutVid3/index.html","/Vacation/index.html","/Warehouse33/index.html","/Warehouse33/warehouse1.html","/Warehouse33/warehouse2.html","/Warehouse33/warehouse4.html","/WeRock/index.html","/wiki1/index.html","/wiki2/index.html","/wiki3/index.html","/yourdata/index.html"],"pageMap":{"/blank.html":"/blank.html","/ascii/index.html":"/ascii/index.html","/bewarned/aliens.html":"/bewarned/aliens.html","/bewarned/arch.html":"/bewarned/arch.html","/bewarned/index.html":"/bewarned/index.html","/bewarned/whydie.html":"/bewarned/whydie.html","/brutal/index.html":"/brutal/index.html","/brutal/signup.html":"/brutal/signup.html","/bugchaser/faq.html":"/BugChaser/faq.html","/bugchaser/index.html":"/BugChaser/index.html","/bugchaser/join.html":"/BugChaser/join.html","/bugchaser/noid.html":"/BugChaser/noid.html","/bugchaser/store.html":"/BugChaser/store.html","/cleanup/burial.html":"/cleanup/burial.html","/cleanup/freezing.html":"/cleanup/freezing.html","/cleanup/index.html":"/cleanup/index.html","/creepyface/index.html":"/CreepyFace/index.html","/crybitch/index.html":"/CryBitch/index.html","/crybitch/login.html":"/CryBitch/login.html","/deepjournal/index.html":"/deepJournal/index.html","/deepjournal/page2.html":"/deepJournal/page2.html","/deepjournal/page3.html":"/deepJournal/page3.html","/docbreather/index.html":"/DocBreather/index.html","/doclucas/index.html":"/DocLucas/index.html","/docmem/index.html":"/DocMem/index.html","/docnode/index.html":"/DocNode/index.html","/docnoir/index.html":"/DocNoir/index.html","/docpolice/index.html":"/DocPolice/index.html","/docstack/index.html":"/DocStack/index.html","/doczonewall/index.html":"/DocZoneWall/index.html","/dontwasteit/index.html":"/dontwasteit/index.html","/dontwasteit/no.html":"/dontwasteit/no.html","/dontwasteit/yes.html":"/dontwasteit/yes.html","/dronespy/index.html":"/dronespy/index.html","/dronespy/spyforme.html":"/dronespy/spyforme.html","/dronespy/videos.html":"/dronespy/videos.html","/evidencelocker/confiscated.html":"/evidencelocker/confiscated.html","/evidencelocker/contribute.html":"/evidencelocker/contribute.html","/evidencelocker/index.html":"/evidencelocker/index.html","/evidencelocker/leaked.html":"/evidencelocker/leaked.html","/evidencelocker/purchase.html":"/evidencelocker/purchase.html","/evilcollection/ab.html":"/EvilCollection/ab.html","/evilcollection/ab2.html":"/EvilCollection/ab2.html","/evilcollection/baby.html":"/EvilCollection/baby.html","/evilcollection/chat.html":"/EvilCollection/chat.html","/evilcollection/creepypics.html":"/EvilCollection/creepypics.html","/evilcollection/index.html":"/EvilCollection/index.html","/evilcollection/link.html":"/EvilCollection/link.html","/evilcollection/memes.html":"/EvilCollection/memes.html","/evilcollection/pics.html":"/EvilCollection/pics.html","/evilcollection/randompics.html":"/EvilCollection/randompics.html","/eye/index.html":"/eye/index.html","/fatherdonald/index.html":"/fatherdonald/index.html","/fatherdonald/join.html":"/fatherdonald/join.html","/footdoctor/homemade.html":"/FootDoctor/homemade.html","/footdoctor/index.html":"/FootDoctor/index.html","/footdoctor/myfavoritefeet.html":"/FootDoctor/myfavoritefeet.html","/footdoctor/sendmepics.html":"/FootDoctor/sendmepics.html","/forgiveme/confess.html":"/ForgiveMe/confess.html","/forgiveme/index.html":"/ForgiveMe/index.html","/fortunecookie/index.html":"/fortuneCookie/index.html","/genshare/index.html":"/genshare/index.html","/granddaddy/contact.html":"/granddaddy/contact.html","/granddaddy/error.html":"/granddaddy/error.html","/granddaddy/gallery.html":"/granddaddy/gallery.html","/granddaddy/index.html":"/granddaddy/index.html","/grandmasfantasy/index.html":"/GrandmasFantasy/index.html","/grandmasfantasy/older.html":"/GrandmasFantasy/older.html","/heirloom/containers.html":"/Heirloom/containers.html","/heirloom/error.html":"/Heirloom/error.html","/heirloom/index.html":"/Heirloom/index.html","/heirloom/order.html":"/Heirloom/order.html","/heirloom/pgpkey.html":"/Heirloom/pgpkey.html","/heirloom/quality.html":"/Heirloom/quality.html","/heirloom/specials.html":"/Heirloom/specials.html","/heirloom/walletid.html":"/Heirloom/walletid.html","/hiddenpleasures/buy.html":"/HiddenPleasures/buy.html","/hiddenpleasures/index.html":"/HiddenPleasures/index.html","/hiddenpleasures/message.html":"/HiddenPleasures/message.html","/hiddenpleasures/range1.html":"/HiddenPleasures/range1.html","/hiddenpleasures/range2.html":"/HiddenPleasures/range2.html","/hiddenpleasures/range3.html":"/HiddenPleasures/range3.html","/hiddenpleasures/range4.html":"/HiddenPleasures/range4.html","/hiddenpleasures/range5.html":"/HiddenPleasures/range5.html","/hiddenpleasures/requestsale.html":"/HiddenPleasures/requestsale.html","/hiddenpleasures/signin.html":"/HiddenPleasures/signin.html","/iamhere/index.html":"/Iamhere/index.html","/ilovecats/contact.html":"/IloveCats/contact.html","/ilovecats/index.html":"/IloveCats/index.html","/ilovecats/mycats.html":"/IloveCats/mycats.html","/isevil/index.html":"/isevil/index.html","/keepsake/index.html":"/keepsake/index.html","/killforme/index.html":"/killforme/index.html","/killforme/instructions.html":"/killforme/instructions.html","/killforme/targets.html":"/killforme/targets.html","/littlefriends/error.html":"/littleFriends/error.html","/littlefriends/index.html":"/littleFriends/index.html","/milksupply/index.html":"/milksupply/index.html","/milksupply/milkpictures.html":"/milksupply/milkpictures.html","/mortalmasks/how.html":"/mortalmasks/how.html","/mortalmasks/index.html":"/mortalmasks/index.html","/mortalmasks/order.html":"/mortalmasks/order.html","/mutilation/index.html":"/mutilation/index.html","/mutilation/join.html":"/mutilation/join.html","/mutilation/login.html":"/mutilation/login.html","/mutilation/nowallet.html":"/mutilation/nowallet.html","/mydaughter/index.html":"/mydaughter/index.html","/mygut/buy.html":"/mygut/buy.html","/mygut/contact.html":"/mygut/contact.html","/mygut/index.html":"/mygut/index.html","/mygut/shop.html":"/mygut/shop.html","/mygut/special.html":"/mygut/special.html","/myriad/index.html":"/Myriad/index.html","/notfound/index.html":"/NotFound/index.html","/numbers/index.html":"/numbers/index.html","/numbers2/index.html":"/numbers2/index.html","/numberstation/index.html":"/numberStation/index.html","/oneless/index.html":"/oneless/index.html","/pantysales/index.html":"/pantySales/index.html","/paytorape/faq.html":"/PayToRape/faq.html","/paytorape/index.html":"/PayToRape/index.html","/paytorape/pay.html":"/PayToRape/pay.html","/randomsite/gateopen.html":"/RandomSite/gateopen.html","/randomsite/index.html":"/RandomSite/index.html","/replythread/index.html":"/replyThread/index.html","/sacrifice/enter.html":"/sacrifice/enter.html","/sacrifice/index.html":"/sacrifice/index.html","/sacrifice/join.html":"/sacrifice/join.html","/sacrifice/walk.html":"/sacrifice/walk.html","/satan/index.html":"/satan/index.html","/satan/join.html":"/satan/join.html","/screambitch/index.html":"/ScreamBitch/index.html","/thanksforvisiting/babyshrimp.html":"/ThanksForVisiting/babyshrimp.html","/thanksforvisiting/bar.html":"/ThanksForVisiting/bar.html","/thanksforvisiting/black.html":"/ThanksForVisiting/black.html","/thanksforvisiting/creepy.html":"/ThanksForVisiting/creepy.html","/thanksforvisiting/donttalktome.html":"/ThanksForVisiting/donttalktome.html","/thanksforvisiting/evilmonster.html":"/ThanksForVisiting/evilmonster.html","/thanksforvisiting/face.html":"/ThanksForVisiting/face.html","/thanksforvisiting/fakemain.html":"/ThanksForVisiting/fakemain.html","/thanksforvisiting/index.html":"/ThanksForVisiting/index.html","/thanksforvisiting/numbers.html":"/ThanksForVisiting/numbers.html","/thanksforvisiting/posture.html":"/ThanksForVisiting/posture.html","/thanksforvisiting/slide.html":"/ThanksForVisiting/slide.html","/thanksforvisiting/slide2.html":"/ThanksForVisiting/slide2.html","/theblackwaves/index.html":"/TheBlackWaves/index.html","/thebombmaker/index.html":"/thebombmaker/index.html","/thedollmaker/enter.html":"/thedollmaker/enter.html","/thedollmaker/index.html":"/thedollmaker/index.html","/theendforny/index.html":"/TheEndForNY/index.html","/thegrey/centrum.html":"/TheGrey/centrum.html","/thegrey/inanis.html":"/TheGrey/inanis.html","/thegrey/index.html":"/TheGrey/index.html","/thegrey/interius.html":"/TheGrey/interius.html","/thegrey/latus.html":"/TheGrey/latus.html","/thehall/index.html":"/thehall/index.html","/thelightwithin/index.html":"/TheLightWithin/index.html","/thelightwithin/saved.html":"/TheLightWithin/saved.html","/theloogaroo/index.html":"/TheLoogaroo/index.html","/theprey/index.html":"/ThePrey/index.html","/thethree/index.html":"/thethree/index.html","/tutkeydis/index.html":"/TutKeyDis/index.html","/tutvid1/index.html":"/tutVid1/index.html","/tutvid2/index.html":"/tutVid2/index.html","/tutvid3/index.html":"/tutVid3/index.html","/vacation/index.html":"/Vacation/index.html","/warehouse33/index.html":"/Warehouse33/index.html","/warehouse33/warehouse1.html":"/Warehouse33/warehouse1.html","/warehouse33/warehouse2.html":"/Warehouse33/warehouse2.html","/warehouse33/warehouse4.html":"/Warehouse33/warehouse4.html","/werock/index.html":"/WeRock/index.html","/wiki1/index.html":"/wiki1/index.html","/wiki2/index.html":"/wiki2/index.html","/wiki3/index.html":"/wiki3/index.html","/yourdata/index.html":"/yourdata/index.html"},"aliasIndex":{"avesatan.ann":0,"fake9.ann":1,"fake26.ann":2,"mydaughter.ann":3,"brutalunderground.ann":4,"bugchaser.ann":5,"fake3.ann":6,"fake13.ann":7,"fake10.ann":8,"cleanup.ann":9,"fake17.ann":10,"fake5.ann":11,"crybitch.ann":12,"fake27.ann":13,"deepjournal.ann":14,"fake24.ann":15,"fake1.ann":16,"dontwasteit.ann":17,"fake18.ann":18,"dronespy.ann":19,"encrave.ann":20,"evidencelocker.ann":21,"evilcollection.ann":22,"eye.ann":23,"fake6.ann":24,"fatherdonald.ann":25,"numbers2.ann":26,"fake15.ann":27,"fake11.ann":28,"footdoctor.ann":29,"forgiveme.ann":30,"fortunecookie.ann":31,"fake29.ann":32,"fake25.ann":33,"grandmasfantasy.ann":34,"fake19.ann":35,"fake4.ann":36,"fake30.ann":37,"heirloom.ann":38,"hiddenpleasures.ann":39,"fake14.ann":40,"ilovecats.ann":41,"iamhere.ann":42,"fake2.ann":43,"isevil.ann":44,"keepsake.ann":45,"killforme.ann":46,"fake7.ann":47,"littlefriends.ann":48,"milksupply.ann":49,"mortalmasks.ann":50,"mutilation.ann":51,"mygut.ann":52,"myriad.ann":53,"numberstation.ann":54,"oneless.ann":55,"orderofnine.ann":56,"pantysales.ann":57,"fake12.ann":58,"paytorape.ann":59,"numbers.ann":60,"fake16.ann":61,"screambitch.ann":62,"fake28.ann":63,"shareyourgenitals.ann":64,"fake20.ann":65,"fake21.ann":66,"bewarned.ann":67,"fake8.ann":68,"creepyface.ann":69,"thanksforvisiting.ann":70,"fake22.ann":71,"theblackwaves.ann":72,"thebombmaker.ann":73,"fake23.ann":74,"wiki1.ann":75,"wiki2.ann":76,"wiki3.ann":77,"thedollmaker.ann":78,"theendofny.ann":79,"thegranddaddy.ann":80,"thegrey.ann":81,"thehall.ann":82,"thelightwithin.ann":83,"theloogaroo.ann":84,"themagistri.ann":85,"theprey.ann":86,"theruleofthree.ann":87,"vacation.ann":88,"warehouse33.ann":89,"werock.ann":90,"ascii.ann":91,"yourdata.ann":92},"siteIndex":{"AveSatan":0,"Fake9":1,"Fake26":2,"MyDaughter":3,"BrutalUnderground":4,"BugChaser":5,"Fake3":6,"Fake13":7,"Fake10":8,"CleanUp":9,"Fake17":10,"Fake5":11,"CryBitch":12,"Fake27":13,"DeepJournal":14,"Fake24":15,"Fake1":16,"DontWasteIt":17,"Fake18":18,"DroneSpy":19,"EnCrave":20,"EvidenceLocker":21,"EvilCollection":22,"Eye":23,"Fake6":24,"FatherDonald":25,"Numbers2":26,"Fake15":27,"Fake11":28,"FootDoctor":29,"ForgiveMe":30,"FortuneCookie":31,"Fake29":32,"Fake25":33,"GrandmasFantasy":34,"Fake19":35,"Fake4":36,"Fake30":37,"Heirloom":38,"HiddenPleasures":39,"Fake14":40,"ILoveCats":41,"IAMHERE":42,"Fake2":43,"IsEvil":44,"KeepSake":45,"KillForMe":46,"Fake7":47,"LittleFriends":48,"MilkSupply":49,"MortalMasks":50,"Mutilation":51,"MyGut":52,"Myriad":53,"NumberStation":54,"Oneless":55,"OrderOfNine":56,"PantySales":57,"Fake12":58,"PayToRape":59,"Numbers":60,"Fake16":61,"ScreamBitch":62,"Fake28":63,"ShareYourGenitals":64,"Fake20":65,"Fake21":66,"BeWarned":67,"Fake8":68,"CreepyFace":69,"ThanksForVisiting":70,"Fake22":71,"TheBlackWaves":72,"TheBombMaker":73,"Fake23":74,"Wiki1":75,"Wiki2":76,"Wiki3":77,"TheDollMaker":78,"TheEndOfNY":79,"TheGranddaddy":80,"TheGrey":81,"TheHall":82,"TheLightWithin":83,"TheLoogaroo":84,"THEMAGISTRI":85,"ThePrey":86,"TheRuleOfThree":87,"Vacation":88,"Warehouse33":89,"WeRock":90,"Ascii":91,"YourData":92},"sites":[{"name":"AveSatan","host":"avesatan.ann","path":"/replyThread/index.html","title":"Ave Satan","description":"100101010101\r","dead":false},{"name":"Fake9","host":"fake9.ann","path":"/NotFound/index.html","title":"BathRoom Cams","description":"Cam site for cams in public restrooms.","dead":true},{"name":"Fake26","host":"fake26.ann","path":"/NotFound/index.html","title":"Black Market","description":"Gun market place.","dead":true},{"name":"MyDaughter","host":"mydaughter.ann","path":"/mydaughter/index.html","title":"Borrow My Daughter","description":"Dieser Inhalt wird nicht übernommen.","dead":false},{"name":"BrutalUnderground","host":"brutalunderground.ann","path":"/brutal/index.html","title":"Brutal Underground","description":"Rape video site claims to be 100% real.","dead":false},{"name":"BugChaser","host":"bugchaser.ann","path":"/BugChaser/index.html","title":"Bug Friendly","description":"A community who like to exchange STDs.","dead":false},{"name":"Fake3","host":"fake3.ann","path":"/NotFound/index.html","title":"Burned At The Stake","description":"Group of people who hunt down \"witches\"","dead":true},{"name":"Fake13","host":"fake13.ann","path":"/NotFound/index.html","title":"Cheap Surgery","description":"Shady doctors selling cheap surgery. ","dead":true},{"name":"Fake10","host":"fake10.ann","path":"/NotFound/index.html","title":"Chosen Awake","description":"Are you awoke?","dead":true},{"name":"CleanUp","host":"cleanup.ann","path":"/cleanup/index.html","title":"Cleaning Services","description":"Not the kind of cleaning you are thinking.","dead":false},{"name":"Fake17","host":"fake17.ann","path":"/NotFound/index.html","title":"Corpses For Sell","description":"Guy selling dead bodies.","dead":true},{"name":"Fake5","host":"fake5.ann","path":"/NotFound/index.html","title":"Cotton Road","description":"Drug marketplace.","dead":true},{"name":"CryBitch","host":"crybitch.ann","path":"/CryBitch/index.html","title":"Cry Bitch","description":"Stalker chan site.","dead":false},{"name":"Fake27","host":"fake27.ann","path":"/NotFound/index.html","title":"DeDo","description":"Hacker group protal site. ","dead":true},{"name":"DeepJournal","host":"deepjournal.ann","path":"/deepJournal/index.html","title":"Deep Journal","description":"Stalker thread of woman.","dead":false},{"name":"Fake24","host":"fake24.ann","path":"/NotFound/index.html","title":"DEEPDOTWEB","description":"News site behind the deep web.","dead":true},{"name":"Fake1","host":"fake1.ann","path":"/NotFound/index.html","title":"DeepVape","description":"The vape nation of the Deep Web","dead":true},{"name":"DontWasteIt","host":"dontwasteit.ann","path":"/dontwasteit/index.html","title":"Dont Waste It","description":"Better not waste it..","dead":false},{"name":"Fake18","host":"fake18.ann","path":"/NotFound/index.html","title":"Dream Place","description":"Pedo forum.","dead":true},{"name":"DroneSpy","host":"dronespy.ann","path":"/dronespy/index.html","title":"Drone Spy","description":"Selling videos of drone footage invading peoples privacy.","dead":false},{"name":"EnCrave","host":"encrave.ann","path":"/RandomSite/index.html","title":"EnCrave","description":"Do NOT break the 9.","dead":false},{"name":"EvidenceLocker","host":"evidencelocker.ann","path":"/evidencelocker/index.html","title":"Evidence Locker","description":"Leaked offical media, pictures and documents. ","dead":false},{"name":"EvilCollection","host":"evilcollection.ann","path":"/EvilCollection/index.html","title":"Evil Collection","description":"Random personal blog site. ","dead":false},{"name":"Eye","host":"eye.ann","path":"/eye/index.html","title":"Eye","description":"?????","dead":false},{"name":"Fake6","host":"fake6.ann","path":"/NotFound/index.html","title":"Family Drug Shop","description":"Family owned drug store.","dead":true},{"name":"FatherDonald","host":"fatherdonald.ann","path":"/fatherdonald/index.html","title":"Father Donald","description":"Creepy old guy with some crazy ideas","dead":false},{"name":"Numbers2","host":"numbers2.ann","path":"/numbers2/index.html","title":"Fifty Seven","description":"Random mysterious page.","dead":false},{"name":"Fake15","host":"fake15.ann","path":"/NotFound/index.html","title":"Flame","description":"Deep web search engine.","dead":true},{"name":"Fake11","host":"fake11.ann","path":"/NotFound/index.html","title":"Flesh Trade","description":"Comunity looking for memebers to trade human flesh.","dead":true},{"name":"FootDoctor","host":"footdoctor.ann","path":"/FootDoctor/index.html","title":"Foot Doctor","description":"Foot fetish collection site.","dead":false},{"name":"ForgiveMe","host":"forgiveme.ann","path":"/ForgiveMe/index.html","title":"Forgive Me","description":"Secretly confess your sins.","dead":false},{"name":"FortuneCookie","host":"fortunecookie.ann","path":"/fortuneCookie/index.html","title":"Fortune Cookie","description":"Test Your Luck.","dead":false},{"name":"Fake29","host":"fake29.ann","path":"/NotFound/index.html","title":"Fuck You!","description":"Yep, pretty much says it all","dead":true},{"name":"Fake25","host":"fake25.ann","path":"/NotFound/index.html","title":"GAME CAT","description":"Expect pleasure. ","dead":true},{"name":"GrandmasFantasy","host":"grandmasfantasy.ann","path":"/GrandmasFantasy/index.html","title":"Grandmas Fantasy","description":"Dieser Inhalt wird nicht übernommen.","dead":false},{"name":"Fake19","host":"fake19.ann","path":"/NotFound/index.html","title":"Hackers4Hire","description":"Hire hackers todo tasks. ","dead":true},{"name":"Fake4","host":"fake4.ann","path":"/NotFound/index.html","title":"Hail Satan","description":"Satanist site.","dead":true},{"name":"Fake30","host":"fake30.ann","path":"/NotFound/index.html","title":"Happy Family","description":"A little too happy.. ","dead":true},{"name":"Heirloom","host":"heirloom.ann","path":"/Heirloom/index.html","title":"Heirloom","description":"Sperm collection store front.","dead":false},{"name":"HiddenPleasures","host":"hiddenpleasures.ann","path":"/HiddenPleasures/index.html","title":"Hidden Pleasures","description":"Dieser Inhalt wird nicht übernommen.","dead":false},{"name":"Fake14","host":"fake14.ann","path":"/NotFound/index.html","title":"Hot Burners","description":"Gun dealer site. ","dead":true},{"name":"ILoveCats","host":"ilovecats.ann","path":"/IloveCats/index.html","title":"I Love Cats","description":"Meow!!","dead":false},{"name":"IAMHERE","host":"iamhere.ann","path":"/Iamhere/index.html","title":"IAMHERE","description":"Or Am I?","dead":false},{"name":"Fake2","host":"fake2.ann","path":"/NotFound/index.html","title":"Illumanti","description":"333","dead":true},{"name":"IsEvil","host":"isevil.ann","path":"/isevil/index.html","title":"Is Evil","description":"Horny?","dead":false},{"name":"KeepSake","host":"keepsake.ann","path":"/keepsake/index.html","title":"Keep Sake","description":"A site that specialize in the dismemberment and preservation of dead tissue.","dead":false},{"name":"KillForMe","host":"killforme.ann","path":"/killforme/index.html","title":"Kill For Me","description":"Looking to make some extra cash?","dead":false},{"name":"Fake7","host":"fake7.ann","path":"/NotFound/index.html","title":"Legion","description":"Hacker group.","dead":true},{"name":"LittleFriends","host":"littlefriends.ann","path":"/littleFriends/index.html","title":"Little Friends","description":"Dieser Inhalt wird nicht übernommen.","dead":false},{"name":"MilkSupply","host":"milksupply.ann","path":"/milksupply/index.html","title":"Milk Supply","description":"Store front for breast milk.","dead":false},{"name":"MortalMasks","host":"mortalmasks.ann","path":"/mortalmasks/index.html","title":"Mortal Masks","description":"Some fucked up dude selling human faces.","dead":false},{"name":"Mutilation","host":"mutilation.ann","path":"/mutilation/index.html","title":"Mutilation","description":"Online cam site for a very special kind of clientele. ","dead":false},{"name":"MyGut","host":"mygut.ann","path":"/mygut/index.html","title":"My Gut","description":"Shit pills.","dead":false},{"name":"Myriad","host":"myriad.ann","path":"/Myriad/index.html","title":"Myriad","description":"A white supremacy site.","dead":false},{"name":"NumberStation","host":"numberstation.ann","path":"/numberStation/index.html","title":"Number Station","description":"What do the numbers mean?!?","dead":false},{"name":"Oneless","host":"oneless.ann","path":"/oneless/index.html","title":"Oneless","description":"No idea WTF this is.","dead":false},{"name":"OrderOfNine","host":"orderofnine.ann","path":"/satan/index.html","title":"Order Of Nine","description":"Dieser Inhalt wird nicht übernommen.","dead":false},{"name":"PantySales","host":"pantysales.ann","path":"/pantySales/index.html","title":"Panty Sales","description":"No description really needed here.","dead":false},{"name":"Fake12","host":"fake12.ann","path":"/NotFound/index.html","title":"Passports R US","description":"Fake passport site.","dead":true},{"name":"PayToRape","host":"paytorape.ann","path":"/PayToRape/index.html","title":"Pay To Rape","description":"Title pretty much says it all","dead":false},{"name":"Numbers","host":"numbers.ann","path":"/numbers/index.html","title":"Red Triangle","description":"Crypto site. ","dead":false},{"name":"Fake16","host":"fake16.ann","path":"/NotFound/index.html","title":"Roses Destruction","description":"Just fucked up..","dead":true},{"name":"ScreamBitch","host":"screambitch.ann","path":"/ScreamBitch/index.html","title":"Scream Bitch","description":"Snuff porn.","dead":false},{"name":"Fake28","host":"fake28.ann","path":"/NotFound/index.html","title":"Secure Drop","description":"Secure webhosting dead drop.","dead":true},{"name":"ShareYourGenitals","host":"shareyourgenitals.ann","path":"/genshare/index.html","title":"Share Your Genitals","description":"Might want to avoid this one.","dead":false},{"name":"Fake20","host":"fake20.ann","path":"/NotFound/index.html","title":"SKYWEB","description":"Deep web hosting company.","dead":true},{"name":"Fake21","host":"fake21.ann","path":"/NotFound/index.html","title":"Snuff Portal","description":"Self explanatory.","dead":true},{"name":"BeWarned","host":"bewarned.ann","path":"/bewarned/index.html","title":"St Louis Arch","description":"Theory behind the power of the St Lous Arch.","dead":false},{"name":"Fake8","host":"fake8.ann","path":"/NotFound/index.html","title":"Tango Down","description":"Hitman for hire website.","dead":true},{"name":"CreepyFace","host":"creepyface.ann","path":"/CreepyFace/index.html","title":"THANATOS","description":"?????????","dead":false},{"name":"ThanksForVisiting","host":"thanksforvisiting.ann","path":"/ThanksForVisiting/index.html","title":"Thanks For Visiting","description":"Just random jiberish.","dead":false},{"name":"Fake22","host":"fake22.ann","path":"/NotFound/index.html","title":"The 8th Sin","description":"Do you do it?","dead":true},{"name":"TheBlackWaves","host":"theblackwaves.ann","path":"/TheBlackWaves/index.html","title":"The Black Waves","description":"Random poem site.","dead":false},{"name":"TheBombMaker","host":"thebombmaker.ann","path":"/thebombmaker/index.html","title":"The Bomb Maker","description":"Some guy who makes bombs to kill people","dead":false},{"name":"Fake23","host":"fake23.ann","path":"/NotFound/index.html","title":"The Butcher","description":"Proper ways of butchering a human body.","dead":true},{"name":"Wiki1","host":"wiki1.ann","path":"/wiki1/index.html","title":"The Deep Wiki","description":"The Deep Wiki directory","dead":false,"directory":true},{"name":"Wiki2","host":"wiki2.ann","path":"/wiki2/index.html","title":"The Deep Wiki II","description":"The Deep Wiki directory","dead":false,"directory":true},{"name":"Wiki3","host":"wiki3.ann","path":"/wiki3/index.html","title":"The Deep Wiki III","description":"The Deep Wiki directory","dead":false,"directory":true},{"name":"TheDollMaker","host":"thedollmaker.ann","path":"/thedollmaker/index.html","title":"The Doll Maker","description":"Some fucked old guy turning young woman into sex dolls.","dead":false},{"name":"TheEndOfNY","host":"theendofny.ann","path":"/TheEndForNY/index.html","title":"The End Of NY","description":"Dooms day prophecy site. ","dead":false},{"name":"TheGranddaddy","host":"thegranddaddy.ann","path":"/granddaddy/index.html","title":"The Granddaddy","description":"Dirty old pervert.","dead":false},{"name":"TheGrey","host":"thegrey.ann","path":"/TheGrey/index.html","title":"The Grey","description":"Will you walk in the shade?","dead":false},{"name":"TheHall","host":"thehall.ann","path":"/thehall/index.html","title":"The Hall","description":"Don't enter...","dead":false},{"name":"TheLightWithin","host":"thelightwithin.ann","path":"/TheLightWithin/index.html","title":"The Light Within","description":"Religious cult site.","dead":false},{"name":"TheLoogaroo","host":"theloogaroo.ann","path":"/TheLoogaroo/index.html","title":"The Loogaroo","description":"Some werid cult with blood","dead":false},{"name":"THEMAGISTRI","host":"themagistri.ann","path":"/sacrifice/index.html","title":"THE MAGISTRI","description":"Portal to secret cult.","dead":false},{"name":"ThePrey","host":"theprey.ann","path":"/ThePrey/index.html","title":"The Prey","description":"Looking for a new sport? ","dead":false},{"name":"TheRuleOfThree","host":"theruleofthree.ann","path":"/thethree/index.html","title":"The Rule Of Three","description":"Thought process behind the rule of three.","dead":false},{"name":"Vacation","host":"vacation.ann","path":"/Vacation/index.html","title":"Vacation","description":"LOL","dead":false},{"name":"Warehouse33","host":"warehouse33.ann","path":"/Warehouse33/index.html","title":"Warehouse 33","description":"Site to showcase their fucked up torture experiments.","dead":false},{"name":"WeRock","host":"werock.ann","path":"/WeRock/index.html","title":"We Rock","description":"Rock collection site.","dead":false},{"name":"Ascii","host":"ascii.ann","path":"/ascii/index.html","title":"YOU THERE?","description":"Some random page with ASCII art.","dead":false},{"name":"YourData","host":"yourdata.ann","path":"/yourdata/index.html","title":"Your Data","description":"Ransomware site.","dead":false}],"wikis":[{"index":1,"path":"/wiki1/index.html","title":"The Deep Wiki","siteNames":["AveSatan","BrutalUnderground","Fake13","Fake10","Fake17","CryBitch","Fake1","Fake18","DroneSpy","EvilCollection","Numbers2","Fake15","Fake11","FortuneCookie","HiddenPleasures","Fake14","IsEvil","LittleFriends","Mutilation","NumberStation","PantySales","Fake12","Fake16","ScreamBitch","CreepyFace","TheBombMaker","Wiki2","Wiki3","TheGranddaddy","TheLightWithin","ThePrey","WeRock"]},{"index":2,"path":"/wiki2/index.html","title":"The Deep Wiki II","siteNames":["Fake26","BugChaser","Fake27","DeepJournal","Fake24","EnCrave","Eye","FootDoctor","Fake25","GrandmasFantasy","Fake19","ILoveCats","Fake2","KeepSake","MilkSupply","MyGut","Oneless","PayToRape","ShareYourGenitals","Fake20","Fake21","ThanksForVisiting","Fake22","Fake23","Wiki1","Wiki3","TheDollMaker","TheGrey","TheLoogaroo","TheRuleOfThree","Vacation","Ascii"]},{"index":3,"path":"/wiki3/index.html","title":"The Deep Wiki III","siteNames":["Fake9","MyDaughter","Fake3","CleanUp","Fake5","DontWasteIt","EvidenceLocker","Fake6","FatherDonald","ForgiveMe","Fake29","Fake4","Fake30","Heirloom","IAMHERE","KillForMe","Fake7","MortalMasks","Myriad","OrderOfNine","Numbers","Fake28","BeWarned","Fake8","TheBlackWaves","Wiki1","Wiki2","TheEndOfNY","TheHall","THEMAGISTRI","Warehouse33","YourData"]}],"unavailablePath":"/NotFound/index.html","puzzleWikiPath":"/wiki3/index.html"};
]==],
	["http://localhost:8000/wttg2-host-bridge.js"] = [==[
/* Inject WTTG2_PORT before this file: {pages:[canonical paths], sites:[
   {host:"local-alias.ann",path:"/site/index.html",title,description,dead:false}
   ], unavailablePath:"/unavailable/index.html"}. Paths stay on this local origin. */
(function (global) {
  var config = global.WTTG2_PORT || {};
  var pages = config.pageMap || Object.create(null);
  var aliases = config.aliasIndex || Object.create(null);
  var sites = config.sites || [];
  var memoryVisited = Object.create(null);
  var origin = global.location.origin;
  var unavailable = config.unavailablePath || '/unavailable/index.html';
  var wikiBuilt = false;
  var namedSites = config.siteIndex || Object.create(null);

  function pathOf(value) {
    var url = new URL(String(value), global.location.href);
    if (url.origin !== origin) return null;
    var path = url.pathname;
    if (path.charAt(path.length - 1) === '/') path += 'index.html';
    return {path:path, suffix:url.search + url.hash};
  }
  for (var i = 0; !config.pageMap && i < (config.pages || []).length; i++) {
    var page = String(config.pages[i]);
    if (page.charAt(0) === '/' && page.charAt(1) !== '/' && !/[?#]/.test(page)) pages[page.toLowerCase()] = page;
  }
  for (var j = 0; !config.aliasIndex && j < sites.length; j++) {
    if (sites[j].host) aliases[String(sites[j].host).toLowerCase()] = j;
    if (sites[j].name) namedSites[sites[j].name] = j;
  }

  function visited(site) {
    if (memoryVisited[site.host]) return true;
    try { return global.localStorage.getItem('wttg2:visited:' + site.host) === '1'; }
    catch (ignored) { return false; }
  }
  function markVisited(site) {
    memoryVisited[site.host] = true;
    try { global.localStorage.setItem('wttg2:visited:' + site.host, '1'); }
    catch (ignored) {}
  }
  function deadURL(site) {
    var canonical = pages[unavailable.toLowerCase()];
    return canonical ? canonical + '?site=' + encodeURIComponent(site.title || site.host) + '&address=' + encodeURIComponent('http://' + site.host) : null;
  }
  function resolve(value) {
    var url;
    try { url = new URL(String(value), global.location.href); }
    catch (ignored) { return null; }
    var alias = aliases[url.hostname.toLowerCase()];
    var site = alias === undefined ? null : sites[alias];
    if (site) {
      if (site.dead) return deadURL(site);
      var sitePath = site.path;
      if (url.pathname !== '/' && url.pathname !== '/index.html') sitePath = site.path.slice(0, site.path.lastIndexOf('/') + 1) + url.pathname.slice(1);
      var known = pages[sitePath.toLowerCase()];
      return known ? known + url.search + url.hash : null;
    }
    if (url.origin !== origin) return null;
    var local = pathOf(url.href);
    var canonical = local && pages[local.path.toLowerCase()];
    return canonical ? canonical + local.suffix : null;
  }
  function navigate(value) {
    var target = resolve(value);
    if (!target) return false;
    for (var i = 0; i < sites.length; i++) {
      var page = sites[i].path || unavailable;
      var base = page.slice(0, page.lastIndexOf('/') + 1).toLowerCase();
      if (!sites[i].dead && base && target.toLowerCase().indexOf(base) === 0) markVisited(sites[i]);
    }
    global.LinkOut();
    global.location.assign(target);
    return false;
  }
  global.LinkClick = navigate;
  global.SiteClick = navigate;
  // The game handles these cursor hooks natively. The host stylesheet assigns
  // the cursor to their actual targets without mutating inherited root styles.
  global.LinkHover = function () {};
  global.LinkOut = function () {};

  function notifyHook(name) {
    document.dispatchEvent(new CustomEvent('wttg2:hook', {detail:{name:name}}));
  }
  // Game-state providers may subscribe; the port invents no keys or hashes.
  global.PlainKeyShow = function () { notifyHook('PlainKeyShow'); };
  global.FileKeyShow = function () { notifyHook('FileKeyShow'); };
  global.HotSpotHit = function () { notifyHook('HotSpotHit'); };
  var gameHooks = ['TestMem', 'TestNode', 'TestStack', 'TestZone', 'KeyPress', 'HolyClick', 'EmptyClick', 'EndVideo', 'puzzleClickedGood', 'puzzleClickedWrong'];
  for (var hookIndex = 0; hookIndex < gameHooks.length; hookIndex++) (function (name) {
    global[name] = function () { notifyHook(name); };
  }(gameHooks[hookIndex]));
  global.puzzleSolved = function () {
    notifyHook('puzzleSolved');
    var target = resolve(config.puzzleWikiPath || '/wiki3/index.html');
    if (!target) return;
    if (typeof global.presentWiki === 'function') global.presentWiki(origin + target);
    var label = document.getElementById('wiki3');
    if (label) {
      label.setAttribute('onMouseOver', 'LinkHover()');
      label.setAttribute('onMouseOut', 'LinkOut()');
      label.setAttribute('onClick', 'LinkClick("' + target + '")');
    }
  };

  function requestStats(method, url, data, callback) {
    var response;
    try {
      var address = new URL(String(url), global.location.href);
      if (address.hostname !== 'wttg2.reflectstudios.com' || address.pathname !== '/stats.php') return null;
      response = method === 'POST' ? {message:'This local archive does not submit confessions.'} : {data:'The original confession service is unavailable in this local archive.'};
    } catch (ignored) { return null; }
    global.setTimeout(function () { if (typeof callback === 'function') callback(JSON.stringify(response)); }, 0);
    return {abort:function () {}};
  }
  function installJQuery() {
    var jquery = global.jQuery;
    if (!jquery || jquery.__wttg2ServicesInstalled) return;
    var get = jquery.get, post = jquery.post;
    jquery.get = function (url, callback) {
      var request = requestStats('GET', url, null, callback);
      return request || (get ? get.apply(jquery, arguments) : null);
    };
    jquery.post = function (url, data, callback) {
      var request = requestStats('POST', url, data, callback);
      return request || (post ? post.apply(jquery, arguments) : null);
    };
    jquery.__wttg2ServicesInstalled = true;
  }

  function escapeText(value) {
    var text = String(value || '');
    if (!/[&<>"|]/.test(text)) return text;
    return text.replace(/[&<>"|]/g, function (character) {
      return {'&':'&amp;', '<':'&lt;', '>':'&gt;', '"':'&quot;', '|':'&#124;'}[character];
    });
  }
  function buildWiki() {
    if (wikiBuilt || !document.getElementById('wikiLinks') || typeof global.BuildWiki !== 'function') return;
    var data = [];
    var wikiSites = sites;
    var wikiRecords = config.wikis || [];
    for (var recordIndex = 0; recordIndex < wikiRecords.length; recordIndex++) {
      if (String(wikiRecords[recordIndex].path).toLowerCase() !== global.location.pathname.toLowerCase()) continue;
      wikiSites = [];
      var members = wikiRecords[recordIndex].siteNames || [];
      for (var memberIndex = 0; memberIndex < members.length; memberIndex++) if (namedSites[members[memberIndex]] !== undefined) wikiSites.push(sites[namedSites[members[memberIndex]]]);
      break;
    }
    for (var i = 0; i < wikiSites.length; i++) {
      var site = wikiSites[i];
      var host = String(site.host || '').replace(/\.ann$/i, '');
      if (!host || !(site.dead ? pages[unavailable.toLowerCase()] : pages[String(site.path).toLowerCase()])) continue;
      data.push(host + '|' + escapeText(site.title) + '|' + escapeText(site.description) + '|' + (visited(site) ? '1' : '0'));
    }
    global.BuildWiki(data);
    wikiBuilt = true;
  }
  global.WTTG2Host = {resolve:resolve, buildWiki:buildWiki, installJQuery:installJQuery, requestStats:requestStats};
  global.addEventListener('load', buildWiki);
  if (document.readyState === 'complete') buildWiki();
}(window));
]==],
	["http://localhost:8000/jQuery.min.js"] = [==[
/* The methods used by the game's basic.js, for the Roblox HTML runtime.
   The desktop preview retains its original jQuery library. */
(function (global) {
  function Query(input) {
    if (!(this instanceof Query)) return new Query(input);
    var values;
    if (typeof input === 'string') values = document.querySelectorAll(input);
    else if (input instanceof Query) return input;
    else values = input == null ? [] : [input];
    this.length = values.length;
    for (var i = 0; i < values.length; i++) this[i] = values[i];
  }
  Query.fn = Query.prototype;
  Query.fn.eq = function (index) {
    if (index < 0) index += this.length;
    return Query(this[index]);
  };
  Query.fn.text = function (value) {
    if (value === undefined) return this.length ? this[0].textContent : '';
    for (var i = 0; i < this.length; i++) this[i].textContent = String(value);
    return this;
  };
  Query.fn.append = function (html) {
    for (var i = 0; i < this.length; i++) {
      var fragment = document.createElement('div');
      fragment.innerHTML = String(html);
      while (fragment.firstChild) this[i].appendChild(fragment.firstChild);
    }
    return this;
  };
  Query.fn.attr = function (name, value) {
    if (value === undefined && typeof name === 'string') return this.length ? this[0].getAttribute(name) : undefined;
    for (var i = 0; i < this.length; i++) {
      if (typeof name === 'object') {
        for (var key in name) this[i].setAttribute(key, name[key]);
      } else this[i].setAttribute(name, value);
    }
    return this;
  };
  Query.fn.css = function (name, value) {
    for (var i = 0; i < this.length; i++) this[i].style.setProperty(name, value);
    return this;
  };
  Query.fn.html = function (value) {
    if (value === undefined) return this.length ? this[0].innerHTML : '';
    for (var i = 0; i < this.length; i++) this[i].innerHTML = String(value);
    return this;
  };
  Query.fn.val = function (value) {
    if (value === undefined) return this.length ? this[0].value : undefined;
    for (var i = 0; i < this.length; i++) this[i].value = String(value);
    return this;
  };
  Query.fn.ready = function (callback) {
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', callback);
    else callback();
    return this;
  };
  Query.fn.on = function (events, callback) {
    var names = String(events).split(/\s+/);
    for (var i = 0; i < this.length; i++) for (var j = 0; j < names.length; j++) if (names[j]) this[i].addEventListener(names[j], callback);
    return this;
  };
  Query.fn.click = function (callback) {
    if (callback !== undefined) return this.on('click', callback);
    for (var i = 0; i < this.length; i++) this[i].click();
    return this;
  };
  Query.fn.removeAttr = function (names) {
    var keys = String(names).split(/\s+/);
    for (var i = 0; i < this.length; i++) for (var j = 0; j < keys.length; j++) if (keys[j]) this[i].removeAttribute(keys[j]);
    return this;
  };
  function changeClass(query, names, add) {
    var changes = String(names).split(/\s+/);
    for (var i = 0; i < query.length; i++) {
      var current = String(query[i].getAttribute('class') || '').split(/\s+/).filter(function (value) { return value !== ''; });
      for (var j = 0; j < changes.length; j++) {
        var index = current.indexOf(changes[j]);
        if (add && index < 0 && changes[j]) current.push(changes[j]);
        else if (!add && index >= 0) current.splice(index, 1);
      }
      query[i].setAttribute('class', current.join(' '));
    }
    return query;
  }
  Query.fn.addClass = function (names) { return changeClass(this, names, true); };
  Query.fn.removeClass = function (names) { return changeClass(this, names, false); };
  Query.fn.data = function (name) {
    if (!this.length) return undefined;
    var value = this[0].getAttribute('data-' + name);
    if (value === null) return undefined;
    var number = Number(value);
    return String(number) === value ? number : value;
  };
  // The archive uses these effects for short service messages. Visibility is
  // immediate in the Roblox adapter; the browser retains original jQuery fades.
  Query.fn.hide = function () { return this.css('display', 'none'); };
  Query.fn.show = function () { return this.css('display', ''); };
  Query.fn.fadeIn = function () { return this.show(); };
  Query.fn.fadeOut = function () { return this.hide(); };
  Query.fn.delay = function () { return this; };
  Query.inArray = function (value, array) { return array.indexOf(value); };
  Query.get = function (url, callback) { return global.WTTG2Host.requestStats('GET', url, null, callback); };
  Query.post = function (url, data, callback) { return global.WTTG2Host.requestStats('POST', url, data, callback); };
  Query.fn.width = function () { return !this.length ? undefined : this[0] === global ? global.innerWidth : this[0].getBoundingClientRect().width; };
  Query.fn.height = function () { return !this.length ? undefined : this[0] === global ? global.innerHeight : this[0].getBoundingClientRect().height; };
  global.jQuery = global.$ = Query;
}(window));
]==],
	["http://localhost:8000/basic.js"] = [==[
$.fn.random = function() {
  return this.eq(Math.floor(Math.random() * this.length));
}

function BuildWiki($WikiData){
	var html = "";
	
	for(var i =0; i < $WikiData.length; i++){
		var siteData = $WikiData[i].split("|");
		var css = "";
		
		if(siteData[3] === "1"){
			css = "visted";
		}
		
		html = html + "<li><a class = '" + css + "' onMouseOver='LinkHover()' onMouseOut='LinkOut()' onClick=\"SiteClick('http://" + siteData[0] + ".ann')\">" + siteData[1] + "</a> - " + siteData[2] + "</li>";
	}
	
	$("#wikiLinks").append(html);
}

function ApplyNudityFilter(){
	$('.nudity').css('-webkit-filter','blur(18px)');
}

function PickPTag(index,hash){
	$('.PTAG').random().text(index + ' - ' + hash);
}

function PickCPTag(){
	var picked = $('.CPTAG').random();
	
	$(picked).attr('onMouseOver', 'LinkHover()');
	$(picked).attr('onMouseOut', 'LinkOut()');
	$(picked).attr('onClick', 'PlainKeyShow()');
}

function PickCFTag(){
	var picked = $('.CFTAG').random();
	
	$(picked).attr('onMouseOver', 'LinkHover()');
	$(picked).attr('onMouseOut', 'LinkOut()');
	$(picked).attr('onClick', 'FileKeyShow()');
}

function randomIntFromInterval(min,max){
    return Math.floor(Math.random()*(max-min+1)+min);
}

function PickHotSpot(){
	SetHotSpot($('.hotZone').random());
}

function SetHotSpot(theHotSpot){
	$(theHotSpot).attr('onMouseOver', 'LinkHover()');
	$(theHotSpot).attr('onMouseOut', 'LinkOut()');
	$(theHotSpot).attr('onClick', 'HotSpotHit()');
}

function PlaceKey(theKeyToPlace){
	if($('#keySpot').length == 0){
		var width = ($(window).width() * 0.8);
		var height = ($(window).height() * 0.8);
		var setX = randomIntFromInterval(10, width);
		var setY = randomIntFromInterval(10, height);
		var html = '<div id = "keySpot" style="top:' + setY + 'px; left:' + setX + 'px;">' + theKeyToPlace + '</div>';
		$("body").append(html);
	}
}]==],
	["http://localhost:8000/thethree/puzzle.js"] = [==[
// don't forget about those
var steps = 6;
var data = [];



function presentWiki(wikiLink){
    $('#wiki3').hide().text(wikiLink).fadeIn();
}

function generateNewData() {
    data = [];
    for(var i = 0; i < steps; i++) {
        data.push( { order: [], current: 0 });
        while(data[i].order.length < 3) {
            var randomNumber = Math.floor(Math.random() * 3) + 1;
            if ($.inArray(randomNumber, data[i].order) == -1) {
                data[i].order.push(randomNumber);
            }
        }
    }
    resetPuzzle();
}

function resetPuzzle() {
    for(var i = 0; i < steps; i++) {
        data[i].current = 0;
    }
    $('.puzzle-spot').removeAttr('onMouseOver onMouseOut onClick').removeClass('clicked');
    $('.puzzle-spot[data-step="1"]').attr({
        'onMouseOver': 'LinkHover()',
        'onMouseOut': 'LinkOut()',
        'onClick': 'SolvePuzzle(this)'
    });
}

function resetStep(step) {
    if (typeof step != 'undefined' && step >= 0 && step < steps) {
        data[step].current = 0;
        $('.puzzle-spot[data-step="'+ (step + 1) + '"]').attr({
            'onMouseOver': 'LinkHover()',
            'onMouseOut': 'LinkOut()',
            'onClick': 'SolvePuzzle(this)'
        }).removeClass('clicked');
    }
}

function SolvePuzzle(e) {
    var $this = $(e);
    var step = $this.data('step') - 1;
    var pick = $this.data('pick');
    var shouldClick = data[step].order[data[step].current];
    if (pick == shouldClick) {
        puzzleClickedGood();
        data[step].current++;
        $('.puzzle-spot[data-step="'+ (step + 1) + '"][data-pick="' + pick + '"]')
            .addClass('clicked')
            .removeAttr('onMouseOver onMouseOut onClick');
        if (data[step].current >= 3) {
            var solvedSteps = 0;
            for(var i = 0; i < steps; i++) {
                solvedSteps += (data[i].current >= 3 ? 1 : 0);
            }
            if (solvedSteps >= steps) {
                puzzleSolved();
            } else {
                $('.puzzle-spot[data-step="' + (step + 2) + '"]').attr({
                    'onMouseOver': 'LinkHover()',
                    'onMouseOut': 'LinkOut()',
                    'onClick': 'SolvePuzzle(this)'
                });
            }
        }
    } else {
        puzzleClickedWrong();
        // If user fucked up should we reset only this one segment (step)
        // or whole puzzle?
        //resetPuzzle();
        //resetStep(step);
        resetPuzzle();
    }
}

$(document).ready(function() {
    generateNewData();
});]==],
}
local dependencies = {
	["http://localhost:8000/blank.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js"},
	["http://localhost:8000/ascii/index.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/bewarned/aliens.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/bewarned/arch.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/bewarned/index.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/bewarned/whydie.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/brutal/index.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/brutal/signup.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/BugChaser/faq.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/BugChaser/index.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/BugChaser/join.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/BugChaser/noid.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/BugChaser/store.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/cleanup/burial.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/cleanup/freezing.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/cleanup/index.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/CreepyFace/index.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/CryBitch/index.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/CryBitch/login.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/deepJournal/index.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/deepJournal/page2.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/deepJournal/page3.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/DocBreather/index.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js"},
	["http://localhost:8000/DocLucas/index.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js"},
	["http://localhost:8000/DocMem/index.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js"},
	["http://localhost:8000/DocNode/index.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js"},
	["http://localhost:8000/DocNoir/index.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js"},
	["http://localhost:8000/DocPolice/index.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js"},
	["http://localhost:8000/DocStack/index.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js"},
	["http://localhost:8000/DocZoneWall/index.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js"},
	["http://localhost:8000/dontwasteit/index.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/dontwasteit/no.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/dontwasteit/yes.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/dronespy/index.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/dronespy/spyforme.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/dronespy/videos.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/evidencelocker/confiscated.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/evidencelocker/contribute.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/evidencelocker/index.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/evidencelocker/leaked.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/evidencelocker/purchase.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/EvilCollection/ab.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/EvilCollection/ab2.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/EvilCollection/baby.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/EvilCollection/chat.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/EvilCollection/creepypics.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/EvilCollection/index.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/EvilCollection/link.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/EvilCollection/memes.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/EvilCollection/pics.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/EvilCollection/randompics.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/eye/index.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/fatherdonald/index.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/fatherdonald/join.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/FootDoctor/homemade.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/FootDoctor/index.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/FootDoctor/myfavoritefeet.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/FootDoctor/sendmepics.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/ForgiveMe/confess.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/ForgiveMe/index.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/fortuneCookie/index.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/genshare/index.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/granddaddy/contact.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/granddaddy/error.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/granddaddy/gallery.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/granddaddy/index.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/GrandmasFantasy/index.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js"},
	["http://localhost:8000/GrandmasFantasy/older.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/Heirloom/containers.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/Heirloom/error.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/Heirloom/index.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/Heirloom/order.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/Heirloom/pgpkey.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/Heirloom/quality.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/Heirloom/specials.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/Heirloom/walletid.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/HiddenPleasures/buy.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js"},
	["http://localhost:8000/HiddenPleasures/index.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js"},
	["http://localhost:8000/HiddenPleasures/message.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js"},
	["http://localhost:8000/HiddenPleasures/range1.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js"},
	["http://localhost:8000/HiddenPleasures/range2.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js"},
	["http://localhost:8000/HiddenPleasures/range3.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js"},
	["http://localhost:8000/HiddenPleasures/range4.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js"},
	["http://localhost:8000/HiddenPleasures/range5.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js"},
	["http://localhost:8000/HiddenPleasures/requestsale.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js"},
	["http://localhost:8000/HiddenPleasures/signin.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js"},
	["http://localhost:8000/Iamhere/index.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/IloveCats/contact.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/IloveCats/index.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/IloveCats/mycats.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/isevil/index.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/keepsake/index.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/killforme/index.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/killforme/instructions.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/killforme/targets.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/littleFriends/error.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js"},
	["http://localhost:8000/littleFriends/index.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js"},
	["http://localhost:8000/milksupply/index.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/milksupply/milkpictures.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/mortalmasks/how.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/mortalmasks/index.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/mortalmasks/order.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/mutilation/index.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/mutilation/join.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/mutilation/login.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/mutilation/nowallet.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/mydaughter/index.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js"},
	["http://localhost:8000/mygut/buy.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/mygut/contact.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/mygut/index.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/mygut/shop.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/mygut/special.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/Myriad/index.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/NotFound/index.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js"},
	["http://localhost:8000/numbers/index.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/numbers2/index.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/numberStation/index.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/oneless/index.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/pantySales/index.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/PayToRape/faq.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/PayToRape/index.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/PayToRape/pay.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/RandomSite/gateopen.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/RandomSite/index.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/replyThread/index.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/sacrifice/enter.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/sacrifice/index.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/sacrifice/join.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/sacrifice/walk.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/satan/index.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js"},
	["http://localhost:8000/satan/join.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/ScreamBitch/index.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/ThanksForVisiting/babyshrimp.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/ThanksForVisiting/bar.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/ThanksForVisiting/black.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/ThanksForVisiting/creepy.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/ThanksForVisiting/donttalktome.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/ThanksForVisiting/evilmonster.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/ThanksForVisiting/face.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/ThanksForVisiting/fakemain.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/ThanksForVisiting/index.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/ThanksForVisiting/numbers.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/ThanksForVisiting/posture.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/ThanksForVisiting/slide.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/ThanksForVisiting/slide2.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/TheBlackWaves/index.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/thebombmaker/index.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/thedollmaker/enter.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/thedollmaker/index.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/TheEndForNY/index.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/TheGrey/centrum.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/TheGrey/inanis.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/TheGrey/index.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/TheGrey/interius.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/TheGrey/latus.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/thehall/index.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/TheLightWithin/index.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/TheLightWithin/saved.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/TheLoogaroo/index.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/ThePrey/index.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/thethree/index.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js", "http://localhost:8000/thethree/puzzle.js"},
	["http://localhost:8000/TutKeyDis/index.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js"},
	["http://localhost:8000/tutVid1/index.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/tutVid2/index.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/tutVid3/index.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/Vacation/index.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/Warehouse33/index.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/Warehouse33/warehouse1.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/Warehouse33/warehouse2.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/Warehouse33/warehouse4.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/WeRock/index.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/wiki1/index.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/wiki2/index.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/wiki3/index.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
	["http://localhost:8000/yourdata/index.html"] = {"http://localhost:8000/wttg2-config.js", "http://localhost:8000/wttg2-host-bridge.js", "http://localhost:8000/jQuery.min.js", "http://localhost:8000/basic.js"},
}
return { forPage = function(url: string): {[string]: string}
	local result = {}
	for _, dependency in ipairs(dependencies[url] or {}) do result[dependency] = sources[dependency] end
	return result
end }

//
//  GameScene.m
//  Prototype
//
//  Created by Nicolas Goles on 9/12/12.
//
//

#import "GameScene.h"
#import "GameManager.h"
#import "Wave.h"
#import "Creep.h"
#import "Waypoint.h"
#import "Tower.h"	
#import "hud.h"

@implementation GameScene

+ (id) scene
{
    CCScene *scene = [CCScene node];
    GameScene *layer = [GameScene node];
    [scene addChild:layer z:1];
    [scene addChild:[Hud sharedManager] z:2];
    
    [[GameManager sharedManager] setGameLayer:layer];
    [[GameManager sharedManager] setHudLayer:[Hud sharedManager]];
    
    return scene;
}

- (id) init
{
    if (self = [super init]) {
        _tileMap = [CCTMXTiledMap tiledMapWithTMXFile:@"TileMap.tmx"];
        _background = [_tileMap layerNamed:@"Background"];
        _background.anchorPoint = ccp(0, 0);
        [self addChild:_tileMap z:0];
        
        // Add WP & Wave
        [self addWaypoints];
        [self addWaves];
        
        // Setup the Game Loop
        [self schedule:@selector(update:)];
        [self schedule:@selector(gameLogic:) interval:1.0];
        
        // Setup current level & position
        _currentLevel = 0;
        self.position = ccp(-280, 0);
    }
    
    return self;
}

- (void) addWaves
{
    Wave *wave = [[Wave alloc] initWithCreepType:[FastRed creep] spawnRate:1.0 creepNumber:25];
    [[GameManager sharedManager].waves addObject:wave];
}

- (void) addWaypoints
{
    CCTMXObjectGroup *objects = [_tileMap objectGroupNamed:@"Objects"];
    Waypoint *waypoint = nil;
    int spawnPointCounter = 0;
    NSMutableDictionary *spawnPoint;
    while ((spawnPoint = [objects objectNamed:[NSString stringWithFormat:@"Waypoint%d", spawnPointCounter]])) {
        int x = [[spawnPoint valueForKey:@"x"] intValue];
        int y = [[spawnPoint valueForKey:@"y"] intValue];

        waypoint = [Waypoint node];
        waypoint.position = ccp(x,y);
        [[GameManager sharedManager].waypoints addObject:waypoint];
        ++spawnPointCounter;
    }
}

- (CGPoint) tileCoordForPosition:(CGPoint) position
{
	int x = position.x / self.tileMap.tileSize.width;
	int y = ((self.tileMap.mapSize.height * self.tileMap.tileSize.height) - position.y) / self.tileMap.tileSize.height;
	
	return ccp(x,y);
}

- (void) addTowerAtPoint:(CGPoint) point
{
	Tower *tower = nil;
	CGPoint towerPosition = [self tileCoordForPosition:point];
	
	int tileGid = [self.background tileGIDAt:towerPosition];
	NSDictionary *props = [self.tileMap propertiesForGID:tileGid];
	NSString *type = [props valueForKey:@"buildable"];
	
	if([type isEqualToString: @"1"]) {
		tower = [BasicTower tower];
		tower.position = ccp((towerPosition.x * 32) + 16, self.tileMap.contentSize.height - (towerPosition.y * 32) - 16);
		[self addChild:tower z:1];
		
		tower.tag = 1;
		[[GameManager sharedManager].towers addObject:tower];
		
	} else {
		NSLog(@"Tile Not Buildable");
	}
    
}

- (BOOL) canBuildAtPosition:(CGPoint) point
{
	CGPoint towerPosition = [self tileCoordForPosition:point];
	int tileGid = [self.background tileGIDAt:towerPosition];
	NSDictionary *properties = [self.tileMap propertiesForGID:tileGid];
	NSString *type = [properties valueForKey:@"buildable"];
	
	if([type isEqualToString: @"1"]) {
		return YES;
	}
	
	return NO;
}

- (Wave *) currentWave
{
    return [[GameManager sharedManager].waves objectAtIndex:_currentLevel];
}

- (Wave *) nextWave
{
    _currentLevel++;
    
    // TODO: Delete later
    if (_currentLevel > 1)
        _currentLevel = 0;
    
    return [[GameManager sharedManager].waves objectAtIndex:_currentLevel];
}

- (void) addTarget
{
	Wave *wave = [self currentWave];
    
	if (wave.totalCreeps < 0) {
		return; // Wave is over
    }
	
	wave.totalCreeps--;
	
    Creep *target = nil;
    
    if ((arc4random() % 2) == 0) {
        target = [FastRed creep];
    } else {
        target = [FastRed creep];
//        target = [StrongGreen creep];
    }
	
	Waypoint *waypoint = [target currentWaypoint];
	target.position = waypoint.position;
	waypoint = [target nextWaypoint];
	
	[self addChild:target z:1];
	
	int moveDuration = target.moveDuration;
	id actionMove = [CCMoveTo actionWithDuration:moveDuration position:waypoint.position];
	id actionMoveDone = [CCCallFuncN actionWithTarget:self selector:@selector(followPath:)];
	[target runAction:[CCSequence actions:actionMove, actionMoveDone, nil]];
	
	// Add to targets array
	target.tag = 1;
	[[GameManager sharedManager].targets addObject:target];
	
}

- (void) followPath:(id) sender
{
	Creep *creep = (Creep *)sender;
	Waypoint *waypoint = [creep nextWaypoint];
    
	id actionMove = [CCMoveTo actionWithDuration:creep.moveDuration position:waypoint.position];
	id actionMoveDone = [CCCallFuncN actionWithTarget:self selector:@selector(followPath:)];
	[creep stopAllActions];
	[creep runAction:[CCSequence actions:actionMove, actionMoveDone, nil]];
}

- (void) gameLogic: (ccTime) dt
{
    static double lastTimeTargetAdded = 0.0;
    Wave *wave = [self currentWave];
    double now = [[NSDate date] timeIntervalSince1970];
    
    // Check if we should add a Creep
    if (lastTimeTargetAdded == 0 || (now - lastTimeTargetAdded) >= wave.spawnRate) {
        [self addTarget];
        lastTimeTargetAdded = now;
    }
}

- (void) update:(ccTime) dt
{
    // Update the game! :D
}

- (CGPoint) boundLayerPos:(CGPoint) newPos
{
    CGSize winSize = [CCDirector sharedDirector].winSize;
    CGPoint retval = newPos;
    retval.x = MIN(retval.x, 0);
    retval.x = MAX(retval.x, -_tileMap.contentSize.width + winSize.width);
    retval.y = MIN(0, retval.y);
    retval.y = MAX(-_tileMap.contentSize.height + winSize.height, retval.y);
    return retval;
}

- (void)handlePanFrom:(UIPanGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        CGPoint touchLocation = [recognizer locationInView:recognizer.view];
        touchLocation = [[CCDirector sharedDirector] convertToGL:touchLocation];
        touchLocation = [self convertToNodeSpace:touchLocation];
        
    } else if (recognizer.state == UIGestureRecognizerStateChanged) {
        CGPoint translation = [recognizer translationInView:recognizer.view];
        translation = ccp(translation.x, -translation.y);
        CGPoint newPos = ccpAdd(self.position, translation);
        self.position = [self boundLayerPos:newPos];
        [recognizer setTranslation:CGPointZero inView:recognizer.view];
        
    } else if (recognizer.state == UIGestureRecognizerStateEnded) {
		float scrollDuration = 0.2;
		CGPoint velocity = [recognizer velocityInView:recognizer.view];
		CGPoint newPos = ccpAdd(self.position, ccpMult(ccp(velocity.x, velocity.y * -1), scrollDuration));
		newPos = [self boundLayerPos:newPos];
        
		[self stopAllActions];
		CCMoveTo *moveTo = [CCMoveTo actionWithDuration:scrollDuration position:newPos];
		[self runAction:[CCEaseOut actionWithAction:moveTo rate:1]];
        
    }
}

@end

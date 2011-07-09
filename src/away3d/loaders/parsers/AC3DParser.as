package away3d.loaders.parsers
{
	import away3d.arcane;
	import away3d.containers.ObjectContainer3D;
	import away3d.core.base.Geometry;
	import away3d.core.base.SubGeometry;
	import away3d.core.base.data.UV;
	import away3d.core.base.data.Vertex;
	import away3d.entities.Mesh;
	import away3d.library.assets.BitmapDataAsset;
	import away3d.loaders.misc.ResourceDependency;
	import away3d.materials.BitmapMaterial;

	import flash.geom.Vector3D;
	import flash.net.URLRequest;
	import flash.utils.ByteArray;

	use namespace arcane;
	
	/**
	 * AC3DParser provides a parser for the AC3D data type.
	 * 
	 * unsupported tags at this state: "MATERIAL", "numsurf","kids","crease","texrep","refs lines of","url","data" and "numvert lines of":
	 */
	public class AC3DParser extends ParserBase
	{
		private var _container:ObjectContainer3D;
		private var _activeContainer:ObjectContainer3D;
		private var _meshList:Vector.<Mesh>;
		private var _inited:Boolean;
		private const LIMIT:uint = 64998;
		private var trunk:Array;
		private var materialIndexList:Array = [];
		private var containersList:Array = [];
		private var tmpos:Vector3D = new Vector3D(0.0,0.0,0.0);
		private var kidsCount:int = 0;
		private var activeMesh:Mesh;
		private var vertexes:Array;
		private var uvs:Array;
		private var parsesV:Boolean;
		private var isQuad:Boolean;
		private var quadCount:int;
		private var invalidPoly:Boolean;
		private var lastType:String = "";
		private var charIndex:uint;
		private var oldIndex:uint;
		private var stringLength:uint;
		
		/**
		 * Creates a new AC3DParser object.
		 * @param uri The url or id of the data or file to be parsed.
		 * @param extra The holder for extra contextual data that the parser might need.
		 */
		
		public function AC3DParser()
		{
			super(ParserDataFormat.PLAIN_TEXT);
		}
		
		/**
		 * Indicates whether or not a given file extension is supported by the parser.
		 * @param extension The file extension of a potential file to be parsed.
		 * @return Whether or not the given file type is supported.
		 */
		public static function supportsType(extension : String) : Boolean
		{
			extension = extension.toLowerCase();
			return extension == "ac";
		}
		
		/**
		 * Tests whether a data block can be parsed by the parser.
		 * @param data The data block to potentially be parsed.
		 * @return Whether or not the given data is supported.
		 */
		public static function supportsData(data : *) : Boolean
		{
			var ba : ByteArray;
			var str : String;
			
			ba = data as ByteArray;
			if (ba) {
				ba.position = 0;
				str = ba.readUTFBytes(4);
			}
			else {
				str = (data is String)? String(data).substr(0, 4) : null;
			}
			
			if (str == 'AC3D')
				return true;
			return false;
		}
		
		/**
		 * @inheritDoc
		 */
		override arcane function resolveDependency(resourceDependency:ResourceDependency):void
		{
			var mesh : Mesh;
			var resource : BitmapDataAsset;
			
			if (resourceDependency.assets.length == 1) {
				resource = resourceDependency.assets[0] as BitmapDataAsset;
				mesh = retrieveMeshFromID(resourceDependency.id);
			}
			
			if(mesh && resource && resource.bitmapData && isBitmapDataValid(resource.bitmapData))
				BitmapMaterial(mesh.material).bitmapData = resource.bitmapData;
		}
		
		override arcane function resolveDependencyFailure(resourceDependency:ResourceDependency):void
		{
			//resourceDependency.id
		}
		
		
		
		/**
		 * @inheritDoc
		 */
		protected override function proceedParsing() : Boolean
		{
			var line:String;
			var creturn:String = String.fromCharCode(10);
			
			// TODO: Remove root container (if it makes sense for this format) and
			// instead return each asset individually using finalizeAsset()
			if (!_container)
				_container = new ObjectContainer3D;
			
			if(_textData.indexOf(creturn) == -1 || _textData.indexOf(creturn)> 10)
				creturn = String.fromCharCode(13);
			
			if(!_inited){
				_inited = true;
				_meshList = new Vector.<Mesh>();
				stringLength = _textData.length;
				
				//version ac3d --> AC3D[b] --> hex value for file format
				//to do add to ParserBase a version getter for supported versions per filetype
				charIndex = _textData.indexOf(creturn, 0);
				oldIndex = charIndex;
				//skip the version header line
				//line = _textData.substring(0, charIndex-1);
				//var version:String = line.substring(line.length-1, line.length);
				//ac3d version = getVersionFromHex(version);
			}
			
			var nameid:String;
			var refscount:int;
			var tUrl:String = "";
			var m:Mesh;
			var cont:ObjectContainer3D;
			
			while(charIndex<stringLength && hasTime()){
				
				charIndex = _textData.indexOf(creturn, oldIndex);
				
				if(charIndex == -1)
					charIndex = stringLength;
				
				line = _textData.substring(oldIndex, charIndex);
				trunk = line.replace("  "," ").replace("  "," ").replace("  "," ").split(" ");
				
				if(charIndex != stringLength)
					oldIndex = charIndex+1;
				
				switch (trunk[0])
				{
					//unused tags
					case "MATERIAL"://MATERIAL "ac3dmat1" rgb 1 1 1  amb 0.2 0.2 0.2  emis 0 0 0  spec 0.2 0.2 0.2  shi 128  trans 0
						//materialList.push(line);//pushing the whole line for now
						//break;
					case "numsurf"://integer
					case "crease"://45.000000. 
					case "texrep":// %f %f tiling
					case "refs lines of":
					case "url":
					case "data":
					case "numvert lines of":
						break;
					
					case "kids"://howmany children in the upcomming object. Probably need it later on, to couple with container/group generation
						kidsCount = parseInt(trunk[1]);
						break;
					
					case "OBJECT":
						
						if(activeMesh != null){
							buildMeshGeometry(activeMesh, vertexes, uvs , tmpos);
							tmpos.x = tmpos.y = tmpos.z = 0;
							activeMesh = null;
						}
						
						if(trunk[1] == "world"){
							lastType = "world";
							_activeContainer = _container;
						}
						
						if(trunk[1] == "poly"){
							var geometry:Geometry = new Geometry();
							activeMesh = new Mesh(null, geometry);
							activeMesh.material = new BitmapMaterial(defaultBitmapData);
							vertexes = [];
							uvs = [];
							activeMesh.name = "m_"+_meshList.length;
							_meshList[_meshList.length] = activeMesh;
							//in case of groups, numvert might not be there
							parsesV = true;
							lastType = "poly";
						}
						
						if(trunk[1] == "group"){
							cont = new ObjectContainer3D();
							_activeContainer.addChild(cont);
							cont.name = "c_"+containersList.length;
							containersList.push(cont);
							_activeContainer = cont;
							lastType = "group";
						}
						
						break;
					
					case "name":
						nameid = line.substring(6, line.length-1);
						if(lastType == "poly"){
							activeMesh.name = nameid;
							activeMesh.material.name = nameid;
						} else{
							_activeContainer.name = nameid;
						}
						break;
					
					case "numvert":
						parsesV = true;
						break;
					
					case "SURF"://0x30
						if(invalidPoly)
							invalidPoly = false;
						break;
					
					case "refs":
						refscount = parseInt(trunk[1]);
						if(refscount == 4){
							isQuad = true;
							quadCount = 0;
						} else if( refscount<3 || refscount > 4){
							trace("AC3D Parser: Unsupported polygon type with "+refscount+" sides found. Triangulate in AC3D!");
							invalidPoly = true;
						} else{
							isQuad = false;
						}
						parsesV = false;
						break;
					
					case "mat":
						materialIndexList.push(trunk[1]);
						break;
					
					case "texture":
						
						tUrl = trunk[1].substring(1,trunk[1].length-1);
						activeMesh.material.name = activeMesh.name;
						addDependency(activeMesh.name, new URLRequest(tUrl));
						
						break;
					
					case "loc"://%f %f %f
						/*
						The translation of the object.  Effectively the definition of the centre of the object.  This is
						relative to the parent - i.e. not a global position.  If this is not found then
						the default centre of the object will be 0, 0, 0.
						*/
						tmpos.x = parseFloat(trunk[1]);
						tmpos.y = parseFloat(trunk[2]);
						tmpos.z = parseFloat(trunk[3]);
						
					case "rot"://%f %f %f  %f %f %f  %f %f %f
						/*The 3x3 rotation matrix for this objects vertices.  Note that the rotation is relative
						to the object's parent i.e. it is not a global rotation matrix.  If this token
						is not specified then the default rotation matrix is 1 0 0, 0 1 0, 0 0 1 */
						//Not required as ac 3d applys rotation to vertexes during export
						//Might be required for containers later on
						//matrix = new Matrix3D();
						
						/*matrix.rawData = Vector.<Number>([parseFloat(trunk[1]),parseFloat(trunk[2]),parseFloat(trunk[3]),0,
						parseFloat(trunk[4]),parseFloat(trunk[5]),parseFloat(trunk[6]),0,
						parseFloat(trunk[7]),parseFloat(trunk[8]),parseFloat(trunk[9]),0,
						0,0,0,1]);*/
						
						//activeMesh.transform = matrix;
						
						break;
					
					default:
						if(trunk[0] == "" || invalidPoly)
							break;
						
						if(parsesV){
							vertexes.push(new Vertex( parseFloat(trunk[0]), parseFloat(trunk[1]), parseFloat(trunk[2])));
							
						} else{
							
							if(isQuad){
								quadCount++;
								if(quadCount == 4){
									uvs.push(uvs[uvs.length-2], uvs[uvs.length-1]);
									uvs.push(parseInt(trunk[0]), new UV(parseFloat(trunk[1]), 1-parseFloat(trunk[2])));
									uvs.push(uvs[uvs.length-10], uvs[uvs.length-9]);
									
								} else{
									uvs.push(parseInt(trunk[0]), new UV(parseFloat(trunk[1]), 1-parseFloat(trunk[2])));
								}
								
							} else {
								
								uvs.push(parseInt(trunk[0]), new UV(parseFloat(trunk[1]), 1-parseFloat(trunk[2])));
								
							}
						}
				}
				
			}
			
			if(charIndex >= stringLength){
				
				if(activeMesh != null)
					buildMeshGeometry(activeMesh, vertexes, uvs, tmpos);
				
				finalizeAsset(_container);
				
				return PARSING_DONE;
			} 
			
			return MORE_TO_PARSE;
		}
		
		private function buildMeshGeometry(mesh:Mesh, vertexes:Array, uvs:Array, tmpos:Vector3D = null):void
		{
			var v0:Vertex;
			var v1:Vertex;
			var v2:Vertex;
			
			var uv0:UV;
			var uv1:UV;
			var uv2:UV;
			
			var vertices:Vector.<Number> = new Vector.<Number>();
			var indices:Vector.<uint> = new Vector.<uint>();
			var vuv:Vector.<Number> = new Vector.<Number>();
			var index:uint = 0;
			var vertLength:uint ;
			
			var subGeomsData:Array = [vertices,indices,vuv];
			
			var j:uint;
			for (var i:uint = 0;i<uvs.length;i+=6){
				
				if(vertLength+9 > LIMIT ){
					index = 0;
					vertLength = 0;
					vertices = new Vector.<Number>();
					indices = new Vector.<uint>();
					vuv = new Vector.<Number>();
					subGeomsData.push(vertices,indices,vuv);
				}
				
				uv0 = uvs[i+1];
				uv1 = uvs[i+3];
				uv2 = uvs[i+5];
				
				v0 = vertexes[uvs[i]];
				v1 = vertexes[uvs[i+2]];
				v2 = vertexes[uvs[i+4]];
				
				vertices.push(v0.x, v0.y, v0.z, v1.x, v1.y, v1.z, v2.x, v2.y, v2.z);
				for(j=0; j<3;++j){
					indices[index] = index;
					index++;
				}
				vuv.push(uv0.u, uv0.v, uv1.u, uv1.v, uv2.u, uv2.v);
				vertLength+=9;
			}
			
			var sub_geom:SubGeometry;
			var geom:Geometry = mesh.geometry;
			
			for(i=0;i<subGeomsData.length;i+=3){
				sub_geom = new SubGeometry();
				geom.addSubGeometry(sub_geom);
				sub_geom.updateVertexData(subGeomsData[i]);
				sub_geom.updateIndexData(subGeomsData[i+1]);
				sub_geom.updateUVData(subGeomsData[i+2]);
			}
			
			_activeContainer.addChild(mesh);
			
			mesh.x = tmpos.x;
			mesh.y = tmpos.y;
			mesh.z = tmpos.z;
		}
		
		private function retrieveMeshFromID(id:String):Mesh
		{
			for(var i:int = 0;i<_meshList.length;++i)
				if(Mesh(_meshList[i]).name == id)
					return Mesh(_meshList[i]);
			
			return null;
		}
		
		/*
		private function getVersionFromHex(char:String):int
		{
		switch (char) 
		{
		case "A": 
		case "a":           
		return 10;
		case "B":
		case "b":
		return 11;
		case "C":
		case "c":
		return 12;
		case "D":
		case "d":
		return 13;
		case "E":
		case "e":
		return 14;                
		case "F":
		case "f":
		return 15;
		default:
		return new Number(char);
		}    
		}
		*/
	}
}


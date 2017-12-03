package com.newgrounds.swivel.swf;
import format.swf.Constants;
import format.swf.Data;
import format.swf.Reader;
import haxe.io.BytesInput;

/**
 * ...
 * @author Newgrounds.com, Inc.
 */

class SwivelSwfReader extends format.swf.Reader {

	public function new(i : BytesInput) {
		bits = new format.tools.BitsInput(i);
		super(i);
	}
		
	public function readPartial() {
		var header = readHeader();
		var tags = new Array();
		while(true) {
			var tag = readTag();
			tags.push(tag);
			switch(tag) {
			case TSandBox(_):
			case TBackgroundColor(_): break;
			default:
			}
		}

		return {header: header, tags: tags, data: i.readAll() };
	}

	// TODO: repeated from SWFReader, to not throw on some incorrect-ish SWF files
	// Is there a way we can avoid repeating this?
	override public function readHeader() : SWFHeader {
		var tag = i.readString(3);
		var compression;
		if( tag == "ZWS" )
			compression = CLZMA;
		else if( tag == "CWS" )
			compression = CZlib;
		else if( tag == "FWS" )
			compression = CUncompressed;
		else
			throw error();
		version = i.readByte();
		var size = readInt();
		
		switch( compression ) {
		case CLZMA:
			var o = new haxe.io.BytesOutput();
			o.bigEndian = false;
			o.write( i.read(5) );
			o.writeInt32( #if haxe3 size - 8 #else haxe.Int32.ofInt(size - 8) #end );
			o.writeInt32( #if haxe3 0 #else haxe.Int32.ofInt(0) #end );
			o.write( i.readAll() );
			var bytes = format.tools.LZMA.decompress( o.getBytes() );
			if( bytes.length + 8 != size ) trace("Compressed data length is incorrect");
			i = new haxe.io.BytesInput(bytes);
		
		case CZlib:
			var bytes = format.tools.Inflate.run(i.readAll());
			if( bytes.length + 8 != size ) trace("Compressed data length is incorrect");
			i = new haxe.io.BytesInput(bytes);
			
		case CUncompressed:
		}
		
		bits = new format.tools.BitsInput(i);
		var r = readRect();
		if( r.left != 0 || r.top != 0 )
			throw error();
		var fps = i.readByte() / 256.0;
		fps += i.readByte();
		var nframes = i.readUInt16();
		return {
			version : version,
			compression : compression,
			width : Std.int(r.right/20),
			height : Std.int(r.bottom/20),
			fps : fps,
			nframes : nframes,
		};
	}
	
	override private function readTagData(id,len) : SWFTag {
		var startPos = untyped i.b.position;

		var tag = super.readTagData(id, len);

		// Assert here
		var endPos = untyped i.b.position;
		if(len != endPos - startPos) {
			#if debug
			trace("Bad tag!");
			#end
			untyped i.b.position = startPos + len;
		}
		
		return tag;
	}
	
}
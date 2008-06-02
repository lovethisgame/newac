(*
  This file is a part of New Audio Components package v 1.8
  Copyright (c) 2002-2008, Andrei Borovsky. All rights reserved.
  See the LICENSE file for more details.
  You can contact me at anb@symmetrica.net
*)

(* $Id$ *)

unit ACS_Streams;

(* Title: ACS_Streams
    Components for raw audio streams.
     These components allow you to handle raw audio (a stream of audio samples without any header).
     They can be used for example while working with audio signals generated by the program itself.*)

interface

uses
  Classes, SysUtils, ACS_Classes;

const

  OUTBUF_SIZE = $4000;
  INBUF_SIZE = $8000;

type

  (* Class: TStreamOut
    This component stores raw audio samples to a TStream-compatible object you provide.*)

  TStreamOut = class(TAuStreamedOutput)
  private
    function GetSR : Integer;
    function GetBPS : Integer;
    function GetCh : Integer;
  protected
    procedure Done; override;
    function DoOutput(Abort : Boolean):Boolean; override;
    procedure Prepare; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
   (* Property: OutSampleRate
      Read this property to get the output data sample rate. *)
    property OutSampleRate : Integer read GetSR;
   (* Property: OutBitsPerSample
      Read this property to get the number of bits per sample in the output data. *)
    property OutBitsPerSample : Integer read GetBPS;
   (* Property: OutChannels
      Read this property to get the number of channels in the output data. *)
    property OutChannels : Integer read GetCh;
  end;

  (* Class: TStreamIn
    This component reads raw audio samples from a TStream-compatible object you provide.*)
  TStreamIn = class(TAuStreamedInput)
  private
    FBPS, FChan, FFreq : LongWord;
    _Buffer : Pointer;
    CurrentBufferSize : LongWord;
  protected
    function GetBPS : LongWord; override;
    function GetCh : LongWord; override;
    function GetSR : LongWord; override;
    procedure GetDataInternal(var Buffer : Pointer; var Bytes : LongWord); override;
    procedure InitInternal; override;
    procedure FlushInternal; override;
    function SeekInternal(var SampleNum : Int64) : Boolean; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  published
   (* Property: InBitsPerSample
      Since raw audio has no descriptive headers providing information about its parameters you should provide this information yourself.
      InBitsPerSample property lets you set the number of bits per sample (8, 16, 24, 32) for the incoming audio data.*)
    property InBitsPerSample : LongWord read FBPS write FBPS;
   (* Property: InChannels
      Since raw audio has no descriptive headers providing information about its parameters you should provide this information yourself.
      InChannels property lets you set the number of channels (1 or more) for the incoming audio data.*)
    property InChannels : LongWord read FChan write FChan;
   (* Property: InSampleRate
      Since raw audio has no descriptive headers providing information about its parameters you should provide this information yourself.
      InSampleRate property lets you set the sample rate (in Hz) for the incoming audio data.*)
    property InSampleRate : LongWord read FFreq write FFreq;
    property EndSample;
    property Loop;
    property StartSample;

    (* Property: Seekable
       By default the TSreamIn component treats the stream it works with as non-seekable.
       Set this property to true if the stream is actually seekable.
    *)
    property Seekable : Boolean read FSeekable write FSeekable;
  end;


implementation

procedure TStreamOut.Prepare;
begin
  if not FStreamAssigned then
  raise EAuException.Create('Stream is not assigned.');
  FInput.Init;
end;

procedure TStreamOut.Done;
begin
  FInput.Flush;
end;

function TStreamOut.DoOutput;
var
  Len : LongWord;
  P : Pointer;
begin
  Result := True;
  if not Busy then Exit;
  if Abort or (not CanOutput) then
  begin
    Result := False;
    Exit;
  end;
  Len := OUTBUF_SIZE;
  Finput.GetData(P, Len);
  if Len > 0 then
  begin
    Result := True;
    FStream.WriteBuffer(P^, Len);
  end
  else Result := False;
end;

constructor TStreamOut.Create;
begin
  inherited Create(AOwner);
end;

destructor TStreamOut.Destroy;
begin
  inherited Destroy;
end;

constructor TStreamIn.Create;
begin
  inherited Create(AOwner);
  FBPS := 8;
  FChan := 1;
  FFreq := 8000;
  FSize := -1;
  FSeekable := False;
  if not (csDesigning	in ComponentState) then
  begin
    CurrentBufferSize := INBUF_SIZE;
    GetMem(_Buffer, CurrentBufferSize);
  end;
end;

destructor TStreamIn.Destroy;
begin
  if not (csDesigning	in ComponentState) then
  begin
    FreeMem(_Buffer);
  end;  
  inherited Destroy;
end;

procedure TStreamIn.InitInternal;
begin
  if Busy then raise EAuException.Create('The component is busy');
  if not Assigned(FStream) then raise EAuException.Create('Stream object not assigned');
  FPosition := FStream.Position;
  Busy := True;
  FSize := FStream.Size;
  FSampleSize := FChan*FBPS div 8;
  FTotalSamples := FSize div FSampleSize;
  if FStartSample > 0 then
  begin
    Seek(StartSample);
    FPosition := 0;
  end;  
  if (FStartSample > 0) or (FEndSample <> -1) then
  begin
    if FEndSample > FTotalSamples then FEndSample := -1;
    if FEndSample = -1 then
      FTotalSamples :=  FTotalSamples - FStartSample + 1
    else
       FTotalSamples := FEndSample - FStartSample + 1;
    FSize := FTotalSamples*FSampleSize;
  end;
end;

procedure TStreamIn.FlushInternal;
begin
//  FStream.Position := 0;
  Busy := False;
end;

procedure TStreamIn.GetDataInternal;
begin
  if Bytes > CurrentBufferSize then
  begin
    CurrentBufferSize := Bytes;
    FreeMem(_Buffer);
    GetMem(_Buffer, CurrentBufferSize);
  end;
  Bytes := FStream.Read(_Buffer^, Bytes);
  Buffer := _Buffer;
end;

function TStreamIn.SeekInternal;
begin
  FStream.Seek(SampleNum*FChan*FBPS div 8, soFromBeginning);
  Result := True;
end;

function TStreamOut.GetSR;
begin
  if not Assigned(Input) then
  raise EAuException.Create('Input is not assigned.');
  Result := FInput.SampleRate;
end;

function TStreamOut.GetBPS;
begin
  if not Assigned(Input) then
  raise EAuException.Create('Input is not assigned.');
  Result := FInput.BitsPerSample;
end;

function TStreamOut.GetCh;
begin
  if not Assigned(Input) then
  raise EAuException.Create('Input is not assigned.');
  Result := FInput.Channels;
end;

function TStreamIn.GetBPS;
begin
  Result := FBPS
end;

function TStreamIn.GetCh;
begin
  Result := FChan;
end;

function TStreamIn.GetSR;
begin
  Result := Self.FFreq;
end;


end.

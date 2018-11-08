;+
; Project     : Sophie/Lindsay jet project
;
; Name        : JET_GET_SPECTROGRAM
;
; Purpose     : Find a PNG image containing the per-detector spectrograms for the 
;				event of interest, and download the PNG.  It is intended that these 
;				spectrograms can be examined by eye before selecting subcollimators to 
;				be included in JET_MAKE_SPEX.
;
; Syntax      : jet_get_spectrogram, flare_num
;
; Inputs      : FLARE_NUM = RHESSI flare list identifier for this flare
;
; Outputs     : NONE, but a PNG file is downloaded from hesperia.gsfc.nasa.gov.
;
; Keywords    : OUT_DIR = output directory in which to store the spectrogram PNG plots
;						  If directory does not exists, it is created.  If no directory 
;						  is specified, the local directory is assumed.
;			  : STOP = keyword to stop procedure, for debugging
;
; Examples	  :
;
;	; Sept 12, 2012 jet
;	flare_num = 12091214
;	jet_get_spectrogram, flare_num
;
; History     : First version 2018 Nov 08, L. Glesener
;-

PRO jet_get_spectrogram, flare_num, out_dir=out_dir, stop=stop

	; Check if the output directory exists.  If not, create it.
	; If no out_dir is set then use current directory.
	if keyword_set( OUT_DIR ) then begin
		if file_search( OUT_DIR ) eq '' then spawn, 'mkdir '+out_dir
	endif else out_dir = './'

	; Retrieve the flare record.
	; Get a year range in which to look for the flare record.
	year = '200'+strmid(strtrim(flare_num,2),0,1)
	if year eq '2001' then year = '20'+strmid(strtrim(flare_num,2),0,2)
	time_year = year+['-jan-01','-dec-31']
	; Pull the flare list for that whole year.  (This could be made more efficient.)
	flare_list_obj =  hsi_flare_list(obs_time_interval =  anytim(time_year, /ecs))
	flare_list =  flare_list_obj -> getdata()
	; Find our flare and set the time range to DELTA_T around peak.
	flare = flare_list( where(flare_list.id_number eq flare_num) )

	; Set up directory in which to search on remote site.
	time_struct = anytim( flare.peak_time, /utc_ext)
	month = strtrim(time_struct.month,2)
	if time_struct.month lt 10 then month = '0'+month
	day = strtrim(time_struct.day,2)
	if time_struct.day lt 10 then day = '0'+day
	path = 'rhessi_extras/spectrograms/counts_plots/'+strtrim(time_struct.year,2) $
		   +'/'+month+'/'+day+'/'
	date = strmid(anytim(flare.peak_time,/yo),0,9)

	; Set up URL object.
	host = 'hesperia.gsfc.nasa.gov'	
	oUrl = OBJ_NEW('IDLnetUrl')
	oUrl->SetProperty, url_scheme = 'https' 
	oUrl->SetProperty, URL_HOST = host
	oUrl->SetProperty, URL_PATH = path
	strings0 = oUrl->Get( /STRING_ARRAY ) 
	pos1 = strpos( strings0, 'hsi_orbit_spec_9dets_' )
	strings1 = strings0
	strings2 = strings0
	strings3 = strings0
	pos1 = strpos( strings0, 'hsi_orbit_spec_9dets_' )
	for i=0, n_elements(strings0)-1 do strings1[i] = strmid( strings0[i], pos1[i] )
	pos2 = strpos( strings1, '.png' )
	for i=0, n_elements(strings2)-1 do strings2[i] = strmid( strings1[i], 0, pos2[i]+4 )
	pos2 = strpos( strings2, '9dets_' )
	for i=0, n_elements(strings3)-1 do strings3[i] = strmid( strings2[i], pos2[i]+15 )
	strings3[ where(strmid(strings3,1,1) eq 'h') ] = ''
	png_times = date+' '+strmid(strings3,0,2)+':'+strmid(strings3,2,2)
	
	i = where( anytim(png_times) gt anytim(flare.peak_time) )
	if (i[0] eq 0) or (i[0] eq -1) then begin
		print, 'Spectrogram files are not in the right time range'
		return
	endif
	the_right_string = strings2[ i[0]-1 ]
	
	oUrl->SetProperty, URL_PATH = path+the_right_string
	fn = oUrl->Get(FILENAME = out_dir+'/'+the_right_string )  
	PRINT, 'filename returned = ', fn

	OBJ_DESTROY, oUrl
	
	spawn, 'open '+fn
	
	if keyword_set( STOP ) then stop
	
END
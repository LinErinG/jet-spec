;+
; Project     : Sophie/Lindsay jet project
;
; Name        : JET_FIT_SPEX
;
; Purpose     : Fit RHESSI spectrum for a jet event of interest.
;				This routine is meant to be used in partnership with JET_MAKE_SPEX.
;				Keywords should be matched between these two routines.
;				The routine fits a VTH + BPOW model.
;
; Syntax      : jet_fit_spex, flare_num
;
; Inputs      : FLARE_NUM = RHESSI flare list identifier for this flare
;
; Outputs     : NONE, but a fit results file and a plot of the fit count spectrum are 
;				written with auto-naming.  Auto-naming is 'ospex_results_12063050.fits' 
;				and 'fit_count_spectrum_12063050.png,' respectively.
;
; Keywords    : BPOW = 	Add a broken power law fit to the default VTH fit.
;				STOP = 	Stop code at the indicated line.  For debugging.
;
; Examples	  :
;
;	; Sept 12, 2012 (Example used for most of the debugging.  All default settings.)
;	flare_num = 12091214
;	jet_make_spex, flare_num
;	jet_fit_spex, flare_num
;	
; 	; June 30, 2012 (Example using the default of 30 sec around flare peak)
;	flare_num = 12063050
;	jet_make_spex, flare_num
;	jet_fit_spex, flare_num
;	Note: an examination of the defaults chosen here show that the default does NOT give 
;	the most optimal interval.  It's missing the high-energy component.
;	
; 	; June 30, 2012 (Example of manually setting a larger fit duration, still around the peak)
;	flare_num = 12063050
;	jet_make_spex, flare_num, delta_t=60.
;	jet_fit_spex, flare_num, delta_t=60.
;
; 	; June 30, 2012 (Example of manually setting the time interval)
;	flare_num = 12063050
;	jet_make_spex, flare_num, time_range='2012-jun-30 '+['1830','1832']
;	jet_fit_spex, flare_num
; 	; This is a much better time interval, and gives a good fit.
;
;
; History     : First version 2018 Oct 23, L. Glesener
;-

PRO	jet_fit_spex, flare_num, bpow=bpow, $
				  stop = stop

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

	; Pick up fitting time range and background time range from the filename.
	f = file_search( 'hsi_spec_'+strtrim(flare_num,2)+'*fits' )
	t0 = strmid( f, strpos( f, '_', 13 )+1, 6 )
	t1 = strmid( f, strpos( f, '_', 20 )+1, 6 )
	t=[t0,t1]
	b0 = strmid( f, strpos( f, 'bkg' )+4, 6 )
	b1 = strmid( f, strpos( f, 'bkg', 20 )+11, 6 )
	b=[b0,b1]
	flare_date = strmid( anytim( flare.peak_time, /yo), 0, 10)
	time_range = flare_date + strmid(t,0,2) +':'+ strmid(t,2,2) +':'+ strmid(t,4,2)
	bkg_time_range = flare_date + strmid(b,0,2) +':'+ strmid(b,2,2) +':'+ strmid(b,4,2)
	
	; Get the observing summary for a large interval for context.
	; Plot this again so we can make sure the intervals are still correct!
	; No need to save the plots again, though.
	obs_obj_wide = hsi_obs_summary()
	obs_obj_wide-> set, obs_time_interval= anytim( time_range )+[-1.,1.]*5.*60
	window, 1, xsi=600, ysi=600
	hsi_linecolors
	!p.multi=[0,1,2]
	obs_obj_wide-> plot, /ylog, dim1_colors=[1,2,3,4,5,6,7,8,9]
	outplot, anytim([time_range[0],time_range[0]],/yo),[1,1.e6]
	outplot, anytim([time_range[1],time_range[1]],/yo),[1,1.e6]
	; Overplot background times on the observing summary.
	obs_obj_wide-> set, obs_time_interval= anytim( time_range )+[-1.,1.]*30.*60.
	obs_obj_wide-> plot, dim1_colors=[1,2,3,4,5,6,7,8,9]
	outplot, anytim([time_range[0],time_range[0]],/yo),[1,1.e6]
	outplot, anytim([time_range[1],time_range[1]],/yo),[1,1.e6]
	outplot, anytim([bkg_time_range[0],bkg_time_range[0]],/yo),[1,1.e6]
	outplot, anytim([bkg_time_range[1],bkg_time_range[1]],/yo),[1,1.e6]
	!p.multi=0

	; Get the observing summary for our actual time of interest to extract attenuator state.
	obs_obj = hsi_obs_summary()
	obs_obj-> set, obs_time_interval= anytim( time_range )
	; Get the attenuator state (there are no changes, since we disallowed that in jet_make_spex).
	flag_changes = obs_obj -> changes()
	atten_state = flag_changes.attenuator_state[0].state
	
	; Construct spec and srm filenames.
	tim = anytim( time_range, /yo )
	tim = strmid( tim,10,2 )+strmid( tim,13,2 )+strmid( tim,16,2 )
	bkg = anytim( bkg_time_range, /yo )
	bkg = strmid( bkg,10,2 )+strmid( bkg,13,2 )+strmid( bkg,16,2 )
	stem = '_'+tim[0]+'_'+tim[1]+'_bkg_'+bkg[0]+'_'+bkg[1]
	specfile = 'hsi_spec_'+strtrim(flare_num,2)+stem+'.fits'
	srmfile  = 'hsi_srm_' +strtrim(flare_num,2)+stem+'.fits'
	
	; Give error if SPEC and SRM files are not found.
	if (file_search(specfile) eq '' or file_search(srmfile) eq '') then begin
		print, 'Error! SPEC or SRM file is missing.'
		return
	endif

	; Choose OSPEX parameters based on whether we're fitting a non-thermal model or not.
	fit_function = 'vth'
	fit_comp_params= [0.1, 1.0, 1.0]
	fit_comp_minima= [1.0e-20, 0.5, 0.01]
	fit_comp_maxima= [1.0e+20, 8.0, 10.0]
	fit_comp_free_mask= [1B, 1B, 0B]
	if keyword_set( BPOW ) then begin
		fit_function += '+bpow'
		fit_comp_params= [ fit_comp_params, 0.000001, 1.70000, 20.0, 5.0]
		fit_comp_minima= [ fit_comp_minima, 1.0e-10, 1.70, 10.00, 1.7]
		fit_comp_maxima= [ fit_comp_maxima, 1.0e+10, 10.0, 40.0, 10.0000]
		fit_comp_free_mask= [ fit_comp_free_mask, 1B, 0B, 1B, 1B]
	endif

	obj = ospex()
	obj-> set, spex_specfile= specfile
	obj-> set, spex_drmfile= srmfile
	obj-> set,spex_bk_time_interval= bkg_time_range
	obj-> set, spex_fit_time_interval = time_range

	obj-> set, fit_function= fit_function
	obj-> set, fit_comp_params= [0.1, 1.0, 1.0, 0.000001, 1.70000, 20.0, 5.0]
	obj-> set, fit_comp_minima= [1.0e-20, 0.5, 0.01, 1.0e-10, 1.70, 10.00, 1.7]
	obj-> set, fit_comp_maxima= [1.0e+20, 8.0, 10.0, 1.0e+10, 10.0, 40.0, 10.0000]
	obj-> set, fit_comp_free_mask= [1B, 1B, 0B, 1B, 0B, 1B, 1B]
	obj-> set, fit_comp_spectrum= ['full', '']
	obj-> set, fit_comp_model= ['chianti', '']
	obj-> set, spex_autoplot_units= 'Flux'
	obj-> set, spex_fitcomp_plot_bk= 1
	obj-> set, spex_fit_manual=0

	; Energy range determination.  Lower edge determined by attenuator state.
	obj-> set, spex_erange = [4.,50.]
	if atten_state eq 1 then obj-> set, spex_erange = [6.,50.]
	if atten_state eq 3 then obj-> set, spex_erange = [10.,50.]
	; Automatically restrict upper energy range for fitting based on a statistical limit
	obj-> set, spex_fit_auto_erange = 1L
	obj-> set, spex_fit_auto_emax_thresh = 10.0		; 10.0 cts/bin is the default threshold.
	; See https://hesperia.gsfc.nasa.gov/ssw/packages/spex/doc/spex_fit_auto_erange_doc.htm for info.

	obj -> dofit, /all

	; Save a plot of the fit spectrum.
	hsi_linecolors
	obj -> plot_spectrum, /no_plotman, /show_fit, /bksub, /overlay_back, $
		   dim1_colors=[1,2,3,4,5,6,7,8,9]
	png_stem = 'fit_count_spectrum_vth_'
	if keyword_set( BPOW ) then png_stem += 'bpow_'
	png_stem += strtrim(flare_num,2)+'.png'
	write_png, png_stem, tvrd(/true)
	
	fits_stem = 'ospex_results_vth_'
	if keyword_set( BPOW ) then fits_stem += 'bpow_'
	fits_stem += strtrim(flare_num,2)+'.fits'
	obj -> savefit, outfile = fits_stem
	; THIS WILL OVERWRITE!

	if keyword_set( STOP ) then stop

END
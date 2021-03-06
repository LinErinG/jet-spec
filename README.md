# jet-spec

Overall workflow:
1 - Get detector spectrograms in order to determine which detectors to use.
2 - Produce spex files (count spectrum and response).  This step pulls up time profiles to show the intervals for analysis and for background, and these choices can be adjusted by manually entering intervals instead.
3 - Perform fit.  Default is a VTH only, but a BPOW can be added via keyword.

; Examples:

; Sept 12, 2012 (Example that was used for most of the debugging.)
; Choose the flare
flare_num = 12091214
; Fetch spectrogram set from Berkeley to use for judging good detectors.
jet_get_spectrogram, flare_num, out_dir='spectrograms'
det_mask=[1,0,1,0,0,1,1,0,1]
; Produce spex files and do the fit.
jet_make_spex, flare_num, det_mask=det_mask, dir_png='lightcurves', dir_fits='spex'
jet_fit_spex, flare_num, in_dir='spex', dir_png='fit_plot', dir_fits='fit_results'

; June 30, 2012 (Example using the default of 30 sec around flare peak)
flare_num = 12063050
jet_make_spex, flare_num
jet_fit_spex, flare_num, in_dir='spex', dir_png='fit_plot', dir_fits='fit_results'
; Note: an examination of the defaults chosen here show that the default does NOT give 
; the most optimal interval.  It's missing the high-energy component.

; June 30, 2012 (Example of manually setting a larger fit duration, still around the peak)
flare_num = 12063050
jet_make_spex, flare_num, delta_t=60.
jet_fit_spex, flare_num, in_dir='spex', dir_png='fit_plot', dir_fits='fit_results'
; This *still* misses the high-energy peak!  For this one, we should choose the time 
; interval by hand.

; June 30, 2012 (Example of manually setting the time interval)
flare_num = 12063050
jet_make_spex, flare_num, time_range='2012-jun-30 '+['1830','1832']
jet_fit_spex, flare_num, in_dir='spex', dir_png='fit_plot', dir_fits='fit_results'
; This is a much better time interval, and gives a good fit.

; June 30, 2012 (Example of manually setting the background time interval, since there 
; are data for quite awhile into the eclipse.)  ALSO FIT NONTHERMAL PART!
flare_num = 12063050
jet_get_spectrogram, flare_num, out_dir='spectrograms'
det_mask=[1,0,1,0,1,1,1,1,1]
jet_make_spex, flare_num, time_range='2012-jun-30 '+['1830','1832'], $
	bkg='2012-jun-30 '+['185032','1900'], det_mask=det_mask, dir_png='lightcurves', dir_fits='spex'
jet_fit_spex, flare_num, /bpow, in_dir='spex', dir_png='fit_plot', dir_fits='fit_results'


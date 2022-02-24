
#-------------------------------------- CONFIGURATION------------------------------------------
proj_name="test"         							# e.g.: "ph-analysis-sample-1"

raw = "Documents/RAW"								# path to raw-files RELATIVE to the /home/user/ location
													# 
													# WARNING: ALL FILES IN THIS DIR WILL BE USED FOR ANALYSIS

fasta="/home/noel/Documents/8-proteins.fasta"		# path to DB of proteins analyzed in FASTA-format
#-----------------------------------------------------------------------------------------------

work_dir = os.environ["HOME"] + "/xquest/analysis/" + proj_name
samples = os.listdir(os.environ["HOME"] + "/" + raw)
mz_samples = [filename.replace(".raw", ".mzXML") for filename in samples]
samples_base = [filename.replace(".raw", "") for filename in samples]

xq_postfixes_per_sample_main = ["matched", "matcheddir", "matched.txt", "matched.txt_isopairs.xls", "matched_isotopepairs.txt"]
xq_files_per_sample_main_dir = ["inclusionlist.xls", "runxq0.sh"]
xq_files_per_sample_nested = ["xquest.def", "xquest.xml", "database.fasta", "db/database.fasta", "db/database.fasta_ion.db", "db/database.fasta_index.stat",
							  "db/database.fasta_peps.db", "db/database.fasta_info.db", "db/database.fasta_peptides.txt"]
xq_postfixes_per_sample_nested= ["matched.stat", "matched.spec.xml", "matched.progress", "matched.stat.done"]

rule convert_RAW_to_MzXML:
	input:
		os.environ["HOME"] + raw + "{sample}.raw"
	params:
		raw = raw,
		work_dir = work_dir,
		proj_name = proj_name
	output:
		work_dir + "/mzxml/{sample}.mzXML"
	shell:
		"""
		mkdir -p {params.work_dir}/mzxml
		sudo docker run -v $HOME:/hm chambm/pwiz-skyline-i-agree-to-the-vendor-licenses wine \
					msconvert /hm/{params.raw}/{sample}.raw --mzXML --32 -o /hm/xquest/analysis/{params.proj_name}/mzxml/
		sudo chown $USER {output}
		"""


rule manage_mzxml:
	input:
		expand(work_dir + "/mzxml/{sample}", sample=mz_samples)
	params:
		work_dir = work_dir
	output:
		work_dir + "/files"
	shell:
		"""
		ls {params.work_dir}/mzxml/ | sed 's/\\(.*\\)\\..*/\\1/' > {params.work_dir}/files
		"""


rule manage_db:
	params: 
		directory=proj_name,
		deffiles=os.environ["HOME"] + "/xquest/deffiles",
		fasta=fasta
	output:
		work_dir + "/db/database.fasta",
		work_dir + "/db/database_decoy.fasta"
	shell:
		"""
		mkdir -p $HOME/xquest/{{results,analysis/{params.directory}/db}}

		cd $HOME/xquest/analysis/{params.directory}/
		ln -sf {params.fasta} db/database.fasta
		xdecoy.pl -db db/database.fasta -out db/database_decoy.fasta
		"""


rule manage_xquest_def:
	input:
		work_dir + "/db/database.fasta",
		work_dir + "/db/database_decoy.fasta"
	params: 
		deffiles=os.environ["HOME"] + "/xquest/deffiles",
		directory=proj_name,
		work_dir=work_dir
	output:
		work_dir + "/xquest.def"
	shell:
		"""
		mkdir -p $HOME/xquest/{{results,analysis/{params.directory}/db}}

		cp {params.deffiles}/xquest.def $HOME/xquest/analysis/{params.directory}
		sed -i "s#/path/to/database/database.fasta#$HOME/xquest/analysis/{params.directory}/db/database.fasta#g" {output}
		sed -i "s#/path/to/decoy-database/database.fasta#$HOME/xquest/analysis/{params.directory}/db/database_decoy.fasta#g" {output}
		cd {params.work_dir}
		gedit xquest.def
		"""


rule manage_xmm_def:
	params: 
		deffiles=os.environ["HOME"] + "/xquest/deffiles",
		directory=proj_name,
		work_dir=work_dir
	output: 
		work_dir + "/xmm.def"
	shell:
		"""
		mkdir -p $HOME/xquest/{{results,analysis/{params.directory}/db}}
		
		cp {params.deffiles}/xmm.def $HOME/xquest/analysis/{params.directory}
		cd {params.work_dir}
		gedit xmm.def
		"""

rule xquest_configure_search:
	input:
		work_dir + "/xmm.def",
		work_dir + "/xquest.def",
		work_dir + "/files",
		work_dir + "/db/database.fasta",
		expand(work_dir + "/mzxml/{filename}", filename=mz_samples)
	params: 
		work_dir
	output:
		expand(work_dir + "/{filename}/{filename}.mzXML", filename=samples_base),
		expand(work_dir + "/{filename}/MASTER_RUN/MASTER_RUN.txt", filename=samples_base),
		expand(work_dir + "/{filename}/xmm.def", filename=samples_base),
		expand(work_dir + "/{filename}/xquest.def", filename=samples_base)
	run:
		import shutil

		for sample in samples_base:
			shutil.rmtree(work_dir + "/" + sample)
		shell(
		"""
		cd {params}
		printf "Configuring the search with pQuest.pl...\n\n"
		pQuest.pl -list files -path {params}/mzxml/
		"""
		)


rule xquest_run_search:
	input:
		work_dir + "/files",
		expand(work_dir + "/{filename}/{filename}.mzXML", filename=samples_base),
		expand(work_dir + "/{filename}/MASTER_RUN/MASTER_RUN.txt", filename=samples_base),
		expand(work_dir + "/{filename}/xmm.def", filename=samples_base),
		expand(work_dir + "/{filename}/xquest.def", filename=samples_base)	
	params: 
		work_dir
	output:
		expand(work_dir + "/{filename}/{filename}_{postfix}", filename=samples_base, postfix=xq_postfixes_per_sample_main),
		expand(work_dir + "/{filename}/{file}", file=xq_files_per_sample_main_dir, filename=samples_base),
		expand(work_dir + "/{filename}/{filename}_matched/{filename}_{postfix}", filename=samples_base, postfix=xq_postfixes_per_sample_nested),
		expand(work_dir + "/{filename}/{filename}_matched/{file}", filename=samples_base, file=xq_files_per_sample_nested),
		work_dir + "/resultdirectories_fullpath",
		work_dir + "/resultdirectories"
	shell:
		"""
		cd {params}
		printf "Running the search...\n\n"
		runXquest.pl -list files -xmlmode -pseudosh
		printf "Running the search... Done.\n\n"
		"""


rule merge_search_results:
	input:
		work_dir + "/files",
		work_dir + "/xmm.def",
		work_dir + "/xquest.def",
		expand(work_dir + "/{filename}/{filename}_{postfix}", filename=samples_base, postfix=xq_postfixes_per_sample_main),
		expand(work_dir + "/{filename}/{file}", file=xq_files_per_sample_main_dir, filename=samples_base),
		expand(work_dir + "/{filename}/{filename}_matched/{filename}_{postfix}", filename=samples_base, postfix=xq_postfixes_per_sample_nested),
		expand(work_dir + "/{filename}/{filename}_matched/{file}", filename=samples_base, file=xq_files_per_sample_nested),
		work_dir + "/resultdirectories_fullpath",
		work_dir + "/resultdirectories"
	params: 
		dir=proj_name, 
		work_dir=work_dir
	output:
		work_dir + "/results/" + proj_name + "/merged_xquest.xml"
	run:
		for sample in samples_base:
			path = work_dir + "/" + sample + "/" + sample + "_matcheddir"
			if not os.path.exists(path):
				os.makedirs(path)
		shell(
			"""
			cd {params.work_dir}
			printf "Merging result files...\n"
			mergexml.pl -list resultdirectories_fullpath -resdir {params.work_dir}/results/{params.dir}
			printf "Merging result files... Done.\n\n"
			"""
			)


rule annotate_results:
	input: 
		work_dir + "/merged_xquest.xml"
	params:
		result_dir=work_dir + "/results/" + proj_name
	output: 
		work_dir + "/results/" + proj_name + "/annotated_xquest.xml"
	shell:
		"""
		cd {params.result_dir}
		printf "Annotating results..."
		annotatexml.pl -xmlfile merged_xquest.xml -out annotated_xquest.xml -native -v
		printf "Annotating results... Done.\n\n"
		"""


rule xprophet_configure:
	input:
		work_dir + "/results/" + proj_name + "/merged_xquest.xml"
	params:
		result_dir=work_dir + "/results/" + proj_name
	output:
		work_dir + "/results/" + proj_name + "/xproph.def"
	shell:
		"""
		cd {params.result_dir}
		printf "Configuring xProphet analysis...\n"
		xprophet.pl
		gedit xproph.def
		printf "Configuring xProphet analysis... Done.\n\n"
		"""


rule xprophet_run:
	input:
		work_dir + "/results/" + proj_name + "/xproph.def"
	params:
		result_dir=work_dir + "/results/" + proj_name
	output:
		work_dir + "/results/" + proj_name + "/xquest.xml"
	shell:
		"""
		cd {params.result_dir}
		printf "Running xProphet...\n"
		xprophet.pl -in annotated_xquest.xml -out xquest.xml
		"""


rule all:
	input:
		work_dir + "/results/" + proj_name + "/xquest.xml"
	params:
		result_dir=work_dir + "/results/" + proj_name
	shell:
		"""
		printf "Copying results to the web server...\nThe script will ask your password to give the correct permissions to Apache 2.\n"
		ln -sf {params.result_dir} $HOME/xquest/results/
		sudo chmod -R 777 $HOME/xquest/results/
		printf "Done.\n\n"

		printf "Display the result manager.\n"
		firefox localhost/cgi-bin/xquest/resultsmanager.cgi
		"""


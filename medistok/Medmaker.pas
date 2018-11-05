Program MakeMedifiles(Input, Output, Batches, Bindexfile, Admin);

USES DOS;

VAR
  Batches, Bindexfile, Admin   :       TEXT;

CONST
  Path='a:\';

BEGIN
  Assign (Batches,path+'batches.med');
  Assign (Bindexfile,path+'batches.ind');
  Assign (Admin,path+'admin.med');
  Rewrite(Batches);
  Rewrite(Bindexfile);
  Rewrite(Admin);
END.
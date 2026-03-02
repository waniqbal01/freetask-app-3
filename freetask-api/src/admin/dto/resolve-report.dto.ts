import { IsEnum, IsNotEmpty } from 'class-validator';

export enum ResolveReportAction {
  DISMISS = 'DISMISS',
  BAN = 'BAN',
}

export class ResolveReportDto {
  @IsNotEmpty()
  @IsEnum(ResolveReportAction)
  action: ResolveReportAction;
}

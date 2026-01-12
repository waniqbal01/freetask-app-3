import { IsIn, IsOptional } from 'class-validator';
import { PaginationQueryDto } from '../../common/dto/pagination-query.dto';

export class JobsQueryDto extends PaginationQueryDto {
  @IsOptional()
  @IsIn(['client', 'freelancer', 'all'], { message: 'filter must be one of: client, freelancer, all' })
  filter?: 'client' | 'freelancer' | 'all';

  @IsOptional()
  status?: string; // Comma-separated enum values
}

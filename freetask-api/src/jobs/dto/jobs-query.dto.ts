import { IsIn, IsOptional } from 'class-validator';
import { PaginationQueryDto } from '../../common/dto/pagination-query.dto';

export class JobsQueryDto extends PaginationQueryDto {
  @IsOptional()
  @IsIn(['client', 'freelancer', 'all'])
  filter?: 'client' | 'freelancer' | 'all';
}

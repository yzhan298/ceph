import { CommonModule } from '@angular/common';
import { NgModule } from '@angular/core';
import { FormsModule, ReactiveFormsModule } from '@angular/forms';
import { RouterModule } from '@angular/router';

import { NgBootstrapFormValidationModule } from 'ng-bootstrap-form-validation';
import { AlertModule } from 'ngx-bootstrap/alert';
import { BsDropdownModule } from 'ngx-bootstrap/dropdown';
import { ModalModule } from 'ngx-bootstrap/modal';
import { ProgressbarModule } from 'ngx-bootstrap/progressbar';
import { TabsModule } from 'ngx-bootstrap/tabs';
import { TooltipModule } from 'ngx-bootstrap/tooltip';

import { SharedModule } from '../../../shared/shared.module';

import { BootstrapCreateModalComponent } from './bootstrap-create-modal/bootstrap-create-modal.component';
import { BootstrapImportModalComponent } from './bootstrap-import-modal/bootstrap-import-modal.component';
import { DaemonListComponent } from './daemon-list/daemon-list.component';
import { EditSiteNameModalComponent } from './edit-site-name-modal/edit-site-name-modal.component';
import { ImageListComponent } from './image-list/image-list.component';
import { MirrorHealthColorPipe } from './mirror-health-color.pipe';
import { OverviewComponent } from './overview/overview.component';
import { PoolEditModeModalComponent } from './pool-edit-mode-modal/pool-edit-mode-modal.component';
import { PoolEditPeerModalComponent } from './pool-edit-peer-modal/pool-edit-peer-modal.component';
import { PoolListComponent } from './pool-list/pool-list.component';

@NgModule({
  entryComponents: [
    BootstrapCreateModalComponent,
    BootstrapImportModalComponent,
    EditSiteNameModalComponent,
    OverviewComponent,
    PoolEditModeModalComponent,
    PoolEditPeerModalComponent
  ],
  imports: [
    CommonModule,
    TabsModule.forRoot(),
    SharedModule,
    RouterModule,
    FormsModule,
    ReactiveFormsModule,
    ProgressbarModule.forRoot(),
    BsDropdownModule.forRoot(),
    ModalModule.forRoot(),
    AlertModule.forRoot(),
    TooltipModule.forRoot(),
    NgBootstrapFormValidationModule
  ],
  declarations: [
    BootstrapCreateModalComponent,
    BootstrapImportModalComponent,
    DaemonListComponent,
    EditSiteNameModalComponent,
    ImageListComponent,
    OverviewComponent,
    PoolEditModeModalComponent,
    PoolEditPeerModalComponent,
    PoolListComponent,
    MirrorHealthColorPipe
  ],
  exports: [OverviewComponent]
})
export class MirroringModule {}
